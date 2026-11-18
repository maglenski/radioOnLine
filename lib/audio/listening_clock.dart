/// Diz qual momento da gravação está saindo no alto-falante.
///
/// O player informa a posição desde que a fonte foi aberta. Só que o player do
/// Android, numa rádio ao vivo, depois de um erro de rede recomeça essa contagem
/// do zero sozinho. Por isso o relógio não usa a posição absoluta: soma só os
/// avanços normais e ignora saltos que o app não pediu.
class ListeningClock {
  /// Maior avanço aceito entre duas leituras. Acima disso é salto, não reprodução.
  static const maxStep = Duration(seconds: 60);

  DateTime? _start;
  Duration _played = Duration.zero;
  Duration _lastRaw = Duration.zero;
  bool _ready = false;

  /// O player foi aberto num ponto gravado em [start]. Ainda não está tocando.
  void open(DateTime start) {
    _start = start;
    _played = Duration.zero;
    _lastRaw = Duration.zero;
    _ready = false;
  }

  /// A fonte abriu: daqui em diante as posições do player valem.
  void ready() {
    _ready = true;
    _lastRaw = Duration.zero;
  }

  /// Nova posição informada pelo player.
  void onPlayerPosition(Duration raw) {
    if (!_ready) return;
    final step = raw - _lastRaw;
    _lastRaw = raw;
    if (step > Duration.zero && step <= maxStep) _played += step;
  }

  /// Momento da gravação que está tocando, ou nulo se nada foi aberto.
  DateTime? get heard => _start?.add(_played);
}
