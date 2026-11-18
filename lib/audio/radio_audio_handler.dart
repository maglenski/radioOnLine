import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/models/station.dart';
import '../core/services/artwork_service.dart';
import '../core/services/diag_log.dart';
import 'listening_clock.dart';
import 'local_stream_server.dart';
import 'stream_relay.dart';
import 'timeshift_buffer.dart';

/// Estado do player que a interface desenha.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.station,
    this.songTitle,
    this.artUrl,
    this.playing = false,
    this.loading = false,
    this.reconnecting = false,
    this.direct = false,
    this.usingFallback = false,
    this.buffered = Duration.zero,
    this.delay = Duration.zero,
    this.sleepRemaining,
    this.error,
    this.atLiveEdge = true,
  });

  final Station? station;
  final String? songTitle;
  final String? artUrl;
  final bool playing;
  final bool loading;
  final bool reconnecting;

  /// Tocando direto da rádio, sem gravação (HLS ou servidor antigo).
  final bool direct;
  final bool usingFallback;

  /// Quanto áudio está gravado (até 30 min).
  final Duration buffered;

  /// Quanto atrás do ao vivo está o que se ouve. Zero = ao vivo.
  final Duration delay;
  final Duration? sleepRemaining;
  final String? error;

  /// O ouvinte não voltou no tempo desde que começou a tocar ou apertou "ao vivo".
  final bool atLiveEdge;

  bool get isLive => atLiveEdge || delay < const Duration(seconds: 5);
}

/// Coração do app: junta gravação ([StreamRelay] + [TimeshiftBuffer]),
/// servidor local e player, e conversa com a notificação / tela de bloqueio.
class RadioAudioHandler extends BaseAudioHandler {
  RadioAudioHandler._(this._buffer, this._artwork)
      : _relay = StreamRelay(_buffer) {
    _server = LocalStreamServer(_buffer, contentType: () => _relay.contentType);
  }

  static Future<RadioAudioHandler> create() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/timeshift');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final handler = RadioAudioHandler._(TimeshiftBuffer(directory: dir), ArtworkService());
    await handler._init();
    return handler;
  }

  static const rewindStep = Duration(seconds: 30);

  /// Ao ir para o ao vivo, começa este tanto antes do último áudio recebido.
  /// É a folga que cobre uma troca de rede sem a música parar. Não atrasa a
  /// partida: esse áudio já está gravado no celular.
  static const liveCushion = Duration(seconds: 8);

  /// No ao vivo, atraso acima disto é corrigido sozinho (rede de segurança).
  static const maxLiveLag = Duration(seconds: 45);

  final TimeshiftBuffer _buffer;
  final StreamRelay _relay;
  final ArtworkService _artwork;
  late final LocalStreamServer _server;
  // As interrupções (ligação, outro app tocando) são tratadas aqui, não pelo
  // player, para a pausa e a retomada passarem pelas mesmas regras do app.
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);

  /// Pausado por mais tempo que isto, o app para de gravar (não gasta dados à toa).
  static const maxPause = Duration(minutes: 30);

  final state = ValueNotifier(const PlaybackSnapshot());

  Station? _station;
  bool _direct = false;
  bool _active = false;
  final _clock = ListeningClock();

  bool _retryPending = false;
  String? _songTitle;
  String? _artUrl;
  String? _error;
  int _playerRetries = 0;
  Timer? _ticker;
  Timer? _sleepTimer;
  Timer? _pauseTimeout;
  bool _interrupted = false;
  DateTime? _sleepAt;
  int _openToken = 0;

  /// Folga natural entre o último byte recebido e o que toca "ao vivo"
  /// (rajada inicial do servidor, buffer do player). Descontada do atraso mostrado,
  /// para o ao vivo aparecer como zero.
  bool _atLiveEdge = true;
  Duration _baseline = Duration.zero;

  Future<void> _init() async {
    await _server.start();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.becomingNoisyEventStream.listen((_) {
      DiagLog.add('sistema: fone desconectado');
      pause();
    });
    session.interruptionEventStream.listen(_onInterruption);

    _player.playbackEventStream.listen(_broadcast, onError: _onPlayerError);
    _player.playingStream.listen((_) => _broadcast());
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && _active) _recover(); // stream local "acabou": reabre
      _publish();
    });
    _player.positionStream.listen(_clock.onPlayerPosition);
    _relay.status.addListener(_publish);
    _relay.usingFallback.addListener(_publish);
    _relay.titles.listen(_onTitle);
    _relay.formatChanges.listen((_) {
      if (_active && !_direct) _openAt(_buffer.startOffset, 'formato mudou');
    });
    // Queda longa demais para emendar: quem está no ao vivo segue do áudio novo,
    // em vez de ficar tocando atrasado. Quem voltou no tempo não é afetado.
    _relay.discontinuities.listen((offset) {
      if (_active && !_direct && _atLiveEdge && _player.playing) {
        _openAt(offset, 'queda longa, segue do áudio novo');
      }
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _publish());
  }

  // ---------- API usada pela interface ----------

  Future<void> playStation(Station station, {bool forceFallback = false}) async {
    final token = ++_openToken;
    _pauseTimeout?.cancel();
    _interrupted = false;
    DiagLog.add('--- ${station.name} ---');
    _relay.stop();
    await _player.stop();
    _buffer.reset();
    _station = station;
    _active = true;
    _direct = false;
    _songTitle = null;
    _artUrl = null;
    _error = null;
    _playerRetries = 0;
    _atLiveEdge = true;
    _baseline = Duration.zero;
    _updateMediaItem();
    _publish(loading: true);

    try {
      await _relay.start(station, forceFallback: forceFallback);
      if (token != _openToken) return;
      await _openAt(_buffer.startOffset, 'play na rádio');
    } on DirectPlaybackRequired {
      if (token != _openToken) return;
      await _playDirect(station);
    } on TimeoutException {
      if (token != _openToken) return;
      // Não chegou nada pelo relay: tenta tocar direto antes de desistir.
      await _playDirect(station);
    } catch (e) {
      _error = 'Não foi possível conectar: $e';
      _publish();
    }
  }

  /// Volta [amount] em relação ao que está tocando.
  Future<void> jumpBack(Duration amount) async {
    final heard = _heardTime;
    if (_direct || heard == null) return;
    _atLiveEdge = false;
    await _openAt(_buffer.offsetAt(heard.subtract(amount)), 'voltar');
  }

  /// Avança [amount]; se passar do ao vivo, vai para o ao vivo.
  Future<void> jumpForward(Duration amount) async {
    final heard = _heardTime;
    if (_direct || heard == null) return;
    final target = heard.add(amount);
    final latest = _buffer.latestTime;
    if (latest == null || target.isAfter(latest.subtract(const Duration(seconds: 5)))) {
      return goLive();
    }
    _atLiveEdge = false;
    await _openAt(_buffer.offsetAt(target), 'avançar');
  }

  /// Toca a partir de [delay] antes do ao vivo (usado pela barra de tempo).
  Future<void> seekToDelay(Duration delay) async {
    final latest = _buffer.latestTime;
    if (_direct || latest == null) return;
    if (delay < const Duration(seconds: 5)) return goLive();
    _atLiveEdge = false;
    await _openAt(_buffer.offsetAt(latest.subtract(delay + _baseline)), 'barra');
  }

  Future<void> goLive() async {
    final latest = _buffer.latestTime;
    if (_direct || latest == null) return;
    _atLiveEdge = true;
    await _openAt(_buffer.offsetAt(latest.subtract(liveCushion)), 'ao vivo');
  }

  void setFallback(bool value) => _relay.setFallback(value);

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepAt = null;
    if (duration != null) {
      _sleepAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        _sleepAt = null;
        pause();
      });
    }
    _publish();
  }

  // ---------- Controles da notificação / tela de bloqueio ----------

  /// Ligação ou outro app tomou o áudio: pausa e, quando devolverem,
  /// continua sozinho de onde parou.
  void _onInterruption(AudioInterruptionEvent event) {
    DiagLog.add('sistema: interrupção ${event.begin ? 'começou' : 'terminou'} (${event.type.name})');
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _player.setVolume(0.3);
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_player.playing) {
            _interrupted = true;
            pause();
          }
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _player.setVolume(1.0);
        case AudioInterruptionType.pause:
          if (_interrupted && _active && !_player.playing) play();
        case AudioInterruptionType.unknown:
          break; // o outro app ficou com o áudio: espera o play manual
      }
      _interrupted = false;
    }
  }

  @override
  Future<void> play() async {
    final station = _station;
    if (station == null) return;
    _pauseTimeout?.cancel();
    if (!_active) return playStation(station);
    DiagLog.add('play depois de pausa');
    if (_direct) return _player.play();
    // Depois de uma pausa reabre no ponto exato (a gravação continuou enquanto isso).
    _atLiveEdge = false;
    await _reopenAtHeard();
  }

  @override
  Future<void> pause() async {
    final heard = _heardTime;
    DiagLog.add('pausa');
    _atLiveEdge = false; // a rádio segue; quem pausou fica para trás
    await _player.pause();
    if (heard != null && !_direct) _pausedAtHeard = heard;
    _pauseTimeout?.cancel();
    _pauseTimeout = Timer(maxPause, () {
      if (_active && !_player.playing) stop();
    });
    _publish();
  }

  DateTime? _pausedAtHeard;

  @override
  Future<void> stop() async {
    DiagLog.add('stop');
    _openToken++;
    _active = false;
    _interrupted = false;
    _pauseTimeout?.cancel();
    _relay.stop();
    await _player.stop();
    _buffer.reset();
    _pausedAtHeard = null;
    setSleepTimer(null);
    _publish();
    await super.stop();
  }

  @override
  Future<void> rewind() => jumpBack(rewindStep);

  @override
  Future<void> fastForward() => jumpForward(rewindStep);

  // ---------- Interno ----------

  /// Momento (horário de gravação) que está saindo no alto-falante.
  DateTime? get _heardTime {
    if (_pausedAtHeard != null && !_player.playing) return _pausedAtHeard;
    return _clock.heard;
  }

  Future<void> _reopenAtHeard() async {
    final heard = _heardTime;
    final oldest = _buffer.oldestTime;
    if (heard == null || oldest == null) return goLive();
    final target = heard.isBefore(oldest) ? oldest : heard;
    await _openAt(_buffer.offsetAt(target), 'continua de onde parou');
  }

  /// Retoma depois de um erro do player: no ao vivo volta para o ao vivo,
  /// senão continua do ponto em que estava.
  Future<void> _recover() {
    if (!_atLiveEdge) return _reopenAtHeard();
    if (_relay.status.value == RelayStatus.streaming) return goLive();
    // Rádio ainda reconectando: espera o áudio novo, sem repetir o que já tocou.
    return _openAt(_buffer.endOffset, 'espera a rádio reconectar');
  }

  /// Quantos segundos antes do último áudio recebido fica a posição [offset].
  int _secondsBehind(int offset) {
    final at = _buffer.timeAt(offset), latest = _buffer.latestTime;
    return (at == null || latest == null) ? 0 : latest.difference(at).inSeconds;
  }

  Future<void> _openAt(int offset, String why) async {
    final token = ++_openToken;
    DiagLog.add('player: abre em -${_secondsBehind(offset)}s ($why)');
    final start = offset < _buffer.startOffset ? _buffer.startOffset : offset;
    _clock.open(_buffer.timeAt(start) ?? DateTime.now());
    _pausedAtHeard = null;
    try {
      await _player.setAudioSource(
        AudioSource.uri(_server.uriFor(start)),
        preload: true,
      );
      if (token != _openToken) return;
      _clock.ready();
      _playerRetries = 0;
      _error = null;
      unawaited(_player.play());
    } catch (e) {
      if (token == _openToken) _onPlayerError(e);
    }
    _publish();
  }

  Future<void> _playDirect(Station station) async {
    _relay.stop();
    _direct = true;
    try {
      final url = _relay.usingFallback.value && station.fallbackUrl != null
          ? station.fallbackUrl!
          : station.streamUrl;
      await _player.setUrl(url);
      unawaited(_player.play());
    } catch (e) {
      _error = 'Esta rádio não respondeu. Tente outra ou confira o endereço.';
    }
    _publish();
  }

  void _onPlayerError(Object e, [StackTrace? st]) {
    DiagLog.add('player: erro $e');
    if (!_active || _retryPending) return;
    // Enquanto a rádio está reconectando, o erro é esperado (não há áudio para
    // entregar): continua tentando sem contar, até a rede voltar.
    if (!_direct && _relay.status.value != RelayStatus.streaming) _playerRetries = 0;
    if (_playerRetries++ < 5) {
      _retryPending = true;
      Future.delayed(const Duration(seconds: 1), () {
        _retryPending = false;
        if (!_active) return;
        _direct ? _playDirect(_station!) : _recover();
      });
    } else {
      _error = 'O player parou de responder. Toque de novo para tentar.';
      _publish();
    }
  }

  Future<void> _onTitle(String title) async {
    if (title == _songTitle) return;
    _songTitle = title;
    _artUrl = null;
    _updateMediaItem();
    _publish();
    final art = await _artwork.find(title);
    if (art != null && title == _songTitle) {
      _artUrl = art;
      _updateMediaItem();
      _publish();
    }
  }

  void _updateMediaItem() {
    final s = _station;
    if (s == null) return;
    final art = _artUrl ?? s.faviconUrl;
    mediaItem.add(MediaItem(
      id: s.id,
      title: _songTitle ?? s.name,
      artist: _songTitle == null ? 'Ao vivo' : s.name,
      album: s.name,
      artUri: art == null ? null : Uri.tryParse(art),
    ));
  }

  void _broadcast([PlaybackEvent? _]) {
    final playing = _player.playing;
    final canShift = !_direct && _active;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (canShift) MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        if (canShift) MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.rewind, MediaAction.fastForward},
      androidCompactActionIndices: canShift ? const [0, 1, 2] : const [0],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.ready,
      }[_player.processingState]!,
      playing: playing,
    ));
    _publish();
  }

  void _publish({bool loading = false}) {
    final heard = _heardTime;
    // O atraso é medido contra o relógio, não contra a chegada do último pedaço
    // de áudio: no 4G/5G o áudio chega em rajadas e a barra ficava indo e vindo.
    final now = DateTime.now();
    var raw = Duration.zero;
    if (!_direct && heard != null && now.isAfter(heard)) raw = now.difference(heard);
    if (_atLiveEdge) {
      // Rede de segurança: no ao vivo o atraso não pode crescer sem o ouvinte pedir.
      if (raw > maxLiveLag &&
          _player.playing &&
          _player.processingState == ProcessingState.ready &&
          _relay.status.value == RelayStatus.streaming) {
        DiagLog.add('vigia: atraso de ${raw.inSeconds}s no ao vivo, corrigindo');
        raw = Duration.zero;
        unawaited(goLive());
      }
      _baseline = raw;
    }
    var delay = raw - _baseline;
    if (delay.isNegative) delay = Duration.zero;
    var buffered = _direct ? Duration.zero : _buffer.bufferedDuration - _baseline;
    if (buffered.isNegative) buffered = Duration.zero;
    final ps = _player.processingState;
    state.value = PlaybackSnapshot(
      station: _station,
      songTitle: _songTitle,
      artUrl: _artUrl,
      playing: _player.playing,
      loading: loading ||
          (_active && (ps == ProcessingState.loading || ps == ProcessingState.buffering)),
      reconnecting: _relay.status.value == RelayStatus.reconnecting,
      direct: _direct,
      usingFallback: _relay.usingFallback.value,
      buffered: buffered,
      delay: delay,
      sleepRemaining: _sleepAt?.difference(DateTime.now()),
      error: _error,
      atLiveEdge: _atLiveEdge,
    );
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    _sleepTimer?.cancel();
    _pauseTimeout?.cancel();
    _relay.dispose();
    await _player.dispose();
    await _server.stop();
    _buffer.dispose();
  }
}
