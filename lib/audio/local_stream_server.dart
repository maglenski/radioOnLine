import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/services/diag_log.dart';
import 'timeshift_buffer.dart';

/// Servidor HTTP em 127.0.0.1 que entrega ao player o áudio do [TimeshiftBuffer]
/// a partir de qualquer posição. Para o player é um stream de rádio comum e
/// infinito; por baixo ele pode estar tocando algo de 20 minutos atrás.
class LocalStreamServer {
  LocalStreamServer(this.buffer, {required this.contentType});

  final TimeshiftBuffer buffer;

  /// Tipo do áudio atual (vem do relay).
  final String Function() contentType;

  HttpServer? _server;
  int _nonce = 0;

  /// Até onde cada endereço já foi entregue. O player do Android, numa rádio
  /// ao vivo, depois de um erro de rede pede o MESMO endereço de novo sem dizer
  /// de onde continuar; sem isto o servidor recomeçava do ponto em que o player
  /// foi aberto e a música voltava minutos.
  final Map<String, int> _delivered = {};

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle, onError: (e) => debugPrint('local server: $e'));
  }

  /// Endereço para tocar a partir de [offset]. O `n` evita reaproveitar conexão antiga.
  Uri uriFor(int offset) {
    final port = _server!.port;
    return Uri.parse('http://127.0.0.1:$port/stream?from=$offset&g=${buffer.generation}&n=${_nonce++}');
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final base = int.tryParse(request.uri.queryParameters['from'] ?? '') ?? buffer.startOffset;
    // Quando o player refaz o pedido depois de um erro, ele manda "Range: bytes=N-"
    // para continuar de onde parou. Sem respeitar isso ele recomeçaria do início.
    final skip = parseRangeStart(request.headers.value(HttpHeaders.rangeHeader));
    final key = '${request.uri.queryParameters['g']}/${request.uri.queryParameters['n']}';
    final resumed = skip == 0 ? _delivered[key] : null;
    if (resumed != null) {
      DiagLog.add('servidor local: player repetiu o pedido, continua de onde parou ($resumed)');
    }
    final from = resumed ?? base + skip;
    final generation = int.tryParse(request.uri.queryParameters['g'] ?? '') ?? buffer.generation;

    response
      ..statusCode = skip > 0 ? HttpStatus.partialContent : HttpStatus.ok
      ..bufferOutput = false
      ..headers.set(HttpHeaders.contentTypeHeader, contentType())
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store')
      ..headers.set(HttpHeaders.connectionHeader, 'close');

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    // Conexão crua: o servidor precisa perceber na hora quando o player larga a
    // conexão (ele faz isso quando a rádio fica muda). Escrever depois disso
    // contaria como entregue um áudio que o player nunca recebeu.
    response.headers.chunkedTransferEncoding = false;
    response.persistentConnection = false;
    final Socket socket;
    try {
      socket = await response.detachSocket(writeHeaders: true);
    } catch (_) {
      return;
    }
    var clientGone = false;
    socket.listen((_) {}, onDone: () => clientGone = true, onError: (_) => clientGone = true);

    var cursor = from;
    try {
      while (generation == buffer.generation && !clientGone) {
        final chunk = buffer.read(cursor, 32 * 1024);
        if (chunk.bytes.isEmpty) {
          await buffer.waitForData();
          continue;
        }
        if (clientGone) break;
        cursor = chunk.offset + chunk.bytes.length;
        socket.add(chunk.bytes);
        await socket.flush(); // segura aqui se o player não está consumindo (pausa)
        _remember(key, cursor);
      }
    } catch (_) {
      // O player fechou a conexão (troca de posição, pausa longa, parada).
    } finally {
      socket.destroy();
    }
  }

  void _remember(String key, int cursor) {
    _delivered.remove(key);
    _delivered[key] = cursor;
    if (_delivered.length > 20) _delivered.remove(_delivered.keys.first);
  }

  /// Início pedido num cabeçalho `Range: bytes=N-`. Zero se ausente ou inválido.
  static int parseRangeStart(String? header) {
    final m = RegExp(r'^bytes=(\d+)-').firstMatch(header?.trim() ?? '');
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
