import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/models/station.dart';
import '../core/services/diag_log.dart';
import 'icy_demuxer.dart';
import 'timeshift_buffer.dart';

enum RelayStatus { idle, connecting, streaming, reconnecting, direct }

/// O stream não dá pra gravar (HLS ou servidor incompatível): tocar direto, sem volta no tempo.
class DirectPlaybackRequired implements Exception {
  DirectPlaybackRequired(this.reason);
  final String reason;
  @override
  String toString() => 'DirectPlaybackRequired: $reason';
}

/// Fala com a rádio, reconecta sozinho e joga o áudio no [TimeshiftBuffer].
///
/// O player nunca fala direto com a rádio: ele lê do buffer pelo servidor local.
/// Assim uma queda de conexão vira só uns segundos de espera, não um erro no player.
class StreamRelay {
  StreamRelay(this.buffer);

  final TimeshiftBuffer buffer;

  final status = ValueNotifier<RelayStatus>(RelayStatus.idle);
  final usingFallback = ValueNotifier<bool>(false);
  final _titles = StreamController<String>.broadcast();
  final _formatChanges = StreamController<void>.broadcast();
  final _discontinuities = StreamController<int>.broadcast();

  /// Título da música (metadados ICY).
  Stream<String> get titles => _titles.stream;

  /// Disparado quando o formato do áudio muda e o buffer foi zerado.
  Stream<void> get formatChanges => _formatChanges.stream;

  /// Disparado quando uma reconexão não pôde ser emendada no áudio já gravado
  /// (a queda foi longa demais). O valor é a posição onde começa o áudio novo.
  Stream<int> get discontinuities => _discontinuities.stream;

  /// Tipo do áudio recebido (`audio/mpeg`, `audio/aac`...).
  String contentType = 'audio/mpeg';

  /// Quantas reconexões em [_failureWindow] fazem trocar para o endereço reserva.
  static const failuresBeforeFallback = 3;
  static const _failureWindow = Duration(minutes: 2);

  /// Sem dados por esse tempo = conexão morta (troca de rede não avisa, só silencia).
  /// Tem que ser menor que a espera do player (8 s) para ele não desistir antes.
  static const _stallTimeout = Duration(seconds: 5);

  /// Tamanho do trecho usado para achar a emenda numa reconexão.
  static const _spliceKey = 2048;

  Station? _station;
  int _session = 0;
  HttpClient? _client;
  final List<DateTime> _failures = [];
  String? _lastContentType;
  String? _lastUrl;
  bool _attemptGotData = false;
  Completer<void>? _firstData;

  /// Começa a receber [station]. Completa quando chegam os primeiros bytes.
  /// Lança [DirectPlaybackRequired] se o stream não puder ser gravado.
  Future<void> start(Station station, {bool forceFallback = false}) {
    stop();
    _station = station;
    usingFallback.value = forceFallback && station.fallbackUrl != null;
    _failures.clear();
    _lastContentType = null;
    _lastUrl = null;
    _firstData = Completer<void>();
    final session = ++_session;
    unawaited(_loop(session));
    return _firstData!.future.timeout(const Duration(seconds: 20));
  }

  /// Troca entre o endereço principal e o reserva sem parar a gravação.
  void setFallback(bool value) {
    if (_station?.fallbackUrl == null || usingFallback.value == value) return;
    usingFallback.value = value;
    _failures.clear();
    _client?.close(force: true); // derruba a conexão atual; o laço reconecta no outro endereço
  }

  void stop() {
    _session++;
    _client?.close(force: true);
    _client = null;
    status.value = RelayStatus.idle;
  }

  Future<void> _loop(int session) async {
    var attempt = 0;
    while (session == _session) {
      final station = _station!;
      final url = usingFallback.value ? station.fallbackUrl! : station.streamUrl;
      status.value = attempt == 0 ? RelayStatus.connecting : RelayStatus.reconnecting;
      final startedAt = DateTime.now();
      _attemptGotData = false;
      var httpError = false;
      try {
        await _receive(session, Uri.parse(url));
      } on DirectPlaybackRequired catch (e) {
        if (session != _session) return;
        status.value = RelayStatus.direct;
        if (!(_firstData?.isCompleted ?? true)) _firstData!.completeError(e);
        return;
      } catch (e) {
        DiagLog.add('rádio: conexão caiu (${_attemptGotData ? 'estava recebendo' : 'não conectou'}): $e');
        httpError = e is HttpException && e.message.startsWith('HTTP ');
      }
      if (session != _session) return;

      // Ficou tocando um bom tempo: a queda foi pontual, recomeça a contagem.
      if (DateTime.now().difference(startedAt) > const Duration(seconds: 60)) attempt = 0;
      attempt++;
      // Só conta para a troca de qualidade a queda de um stream que estava chegando
      // ou a recusa do servidor. Tentativa que nem conectou é falta de rede
      // (troca de WiFi/5G), não problema do endereço.
      if (_attemptGotData || httpError) _registerFailure();
      status.value = RelayStatus.reconnecting;
      // Primeira tentativa na hora; depois 0,5 s, 1 s, 2 s... até 5 s.
      if (attempt > 1) {
        await Future.delayed(
          Duration(milliseconds: min(5000, 500 * pow(2, attempt - 2).toInt())),
        );
      }
    }
  }

  void _registerFailure() {
    final now = DateTime.now();
    _failures.add(now);
    _failures.removeWhere((t) => now.difference(t) > _failureWindow);
    if (!usingFallback.value &&
        _station?.fallbackUrl != null &&
        _failures.length >= failuresBeforeFallback) {
      DiagLog.add('rádio: muitas quedas, trocando para o endereço reserva');
      usingFallback.value = true;
      _failures.clear();
    }
  }

  Future<void> _receive(int session, Uri uri, {int depth = 0}) async {
    if (uri.path.toLowerCase().endsWith('.m3u8')) {
      throw DirectPlaybackRequired('HLS');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..userAgent = 'radioOnLine/1.0 (Flutter)';
    _client = client;
    try {
      final req = await client.getUrl(uri);
      req.headers.set('Icy-MetaData', '1');
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      final HttpClientResponse resp;
      try {
        resp = await req.close();
      } on HttpException catch (e) {
        // Servidores SHOUTcast antigos respondem "ICY 200 OK", que o HttpClient não entende.
        if (e.message.contains('Invalid response')) throw DirectPlaybackRequired('ICY v1');
        rethrow;
      }
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}', uri: uri);
      }

      final mime = resp.headers.contentType?.mimeType.toLowerCase() ?? 'audio/mpeg';
      if (_isPlaylist(mime, uri)) {
        if (depth > 3) throw const HttpException('playlist em laço');
        final body = await resp
            .transform(const Utf8Decoder(allowMalformed: true))
            .join()
            .timeout(const Duration(seconds: 10));
        if (body.contains('#EXT-X-')) throw DirectPlaybackRequired('HLS');
        final next = parsePlaylist(body);
        if (next == null) throw const HttpException('playlist vazia');
        return await _receive(session, Uri.parse(next), depth: depth + 1);
      }

      final formatChanged = _lastContentType != null && _lastContentType != mime;
      if (formatChanged) {
        buffer.reset();
        _formatChanges.add(null);
      }
      _lastContentType = mime;
      contentType = mime;

      // Reconexão no mesmo endereço: o servidor reenvia os últimos segundos.
      // O emendador acha onde o áudio já gravado termina dentro desse reenvio
      // e descarta a repetição, para a música seguir sem pulo e sem atraso.
      final sameUrl = _lastUrl == uri.toString();
      _lastUrl = uri.toString();
      final hasAudio = buffer.endOffset > buffer.startOffset;
      StreamSplicer? splicer;
      if (hasAudio && sameUrl && !formatChanged) {
        final key = buffer.tail(_spliceKey);
        if (key.length == _spliceKey) splicer = StreamSplicer(key);
      }
      var announceBreak = hasAudio && splicer == null && !formatChanged;

      final demux = IcyDemuxer(int.tryParse(resp.headers.value('icy-metaint') ?? ''));
      await for (final chunk in resp.timeout(_stallTimeout)) {
        if (session != _session) return;
        var audio = demux.process(Uint8List.fromList(chunk), _titles.add);
        if (audio.isEmpty) continue;
        _attemptGotData = true;
        if (status.value != RelayStatus.streaming) status.value = RelayStatus.streaming;
        if (splicer != null) {
          final resolved = splicer.add(audio);
          if (resolved == null) continue; // ainda procurando a emenda
          announceBreak = !splicer.matched;
          DiagLog.add(splicer.matched
              ? 'rádio: reconectou e emendou sem perda'
              : 'rádio: reconectou sem emenda (trecho perdido)');
          splicer = null;
          audio = resolved;
        }
        if (audio.isEmpty) continue;
        final at = buffer.endOffset;
        buffer.append(audio);
        if (announceBreak) {
          announceBreak = false;
          _discontinuities.add(at);
        }
        if (!(_firstData?.isCompleted ?? true)) {
          DiagLog.add('rádio: conectou ($mime)');
          _firstData!.complete();
        }
      }
      throw const HttpException('stream encerrado pelo servidor');
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  static bool _isPlaylist(String mime, Uri uri) {
    final p = uri.path.toLowerCase();
    return mime.contains('scpls') ||
        mime.contains('mpegurl') ||
        p.endsWith('.pls') ||
        p.endsWith('.m3u');
  }

  /// Pega o primeiro endereço http(s) de uma playlist .pls ou .m3u.
  static String? parsePlaylist(String body) {
    for (final raw in const LineSplitter().convert(body)) {
      var line = raw.trim();
      final eq = line.indexOf('=');
      if (line.toLowerCase().startsWith('file') && eq > 0) line = line.substring(eq + 1).trim();
      if (line.startsWith('http://') || line.startsWith('https://')) return line;
    }
    return null;
  }

  void dispose() {
    stop();
    _titles.close();
    _formatChanges.close();
    _discontinuities.close();
  }
}

/// Emenda o áudio de uma reconexão no áudio já gravado.
///
/// Servidores Icecast/SHOUTcast mandam, ao conectar, os últimos segundos que já
/// foram ao ar. Se a queda foi curta, esse reenvio contém o fim do que já temos.
/// O emendador segura os primeiros bytes da nova conexão, procura neles a
/// [key] (os últimos bytes gravados) e devolve só o que vem depois dela.
/// Se não achar dentro de [maxBytes] ou [maxWait], devolve tudo como veio.
class StreamSplicer {
  StreamSplicer(
    this.key, {
    this.maxBytes = 768 * 1024,
    this.maxWait = const Duration(milliseconds: 2500),
  });

  final Uint8List key;
  final int maxBytes;
  final Duration maxWait;

  final _pending = BytesBuilder(copy: true);
  final _clock = Stopwatch();
  int _searched = 0;

  /// Verdadeiro se a emenda foi encontrada (reconexão sem perda nem repetição).
  bool matched = false;

  /// Recebe um pedaço. Devolve `null` enquanto procura; quando decide,
  /// devolve o áudio a gravar (pode ser vazio) e não deve mais ser chamado.
  Uint8List? add(Uint8List chunk) {
    if (!_clock.isRunning) _clock.start();
    _pending.add(chunk);
    final data = _pending.toBytes();
    final from = _searched - key.length + 1;
    final i = _indexOf(data, key, from < 0 ? 0 : from);
    if (i >= 0) {
      matched = true;
      return Uint8List.sublistView(data, i + key.length);
    }
    _searched = data.length;
    if (data.length >= maxBytes || _clock.elapsed >= maxWait) return data;
    return null;
  }

  static int _indexOf(Uint8List hay, Uint8List needle, int from) {
    final last = hay.length - needle.length;
    final first = needle[0];
    outer:
    for (var i = from; i <= last; i++) {
      if (hay[i] != first) continue;
      for (var j = 1; j < needle.length; j++) {
        if (hay[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}
