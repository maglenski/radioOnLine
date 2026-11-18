import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Buffer circular em disco que guarda os últimos [window] de áudio recebido.
///
/// Cada byte tem uma posição absoluta (offset) que só cresce. Os bytes antigos
/// são descartados em blocos (segmentos) quando ficam mais velhos que a janela.
/// Junto com os bytes ficam marcações de horário, para converter
/// "voltar 10 minutos" em posição no buffer.
class TimeshiftBuffer {
  TimeshiftBuffer({
    required this.directory,
    this.window = const Duration(minutes: 30),
    this.segmentSize = 256 * 1024,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Directory directory;
  final Duration window;
  final int segmentSize;
  final DateTime Function() _clock;

  final List<_Segment> _segments = [];
  final List<_Mark> _marks = [];
  BytesBuilder _current = BytesBuilder(copy: true);
  int _currentStart = 0;
  DateTime? _currentLastAt;
  int _startOffset = 0;
  int _endOffset = 0;
  int _segmentCounter = 0;
  int _generation = 0;
  Completer<void> _dataSignal = Completer<void>();
  bool _disposed = false;

  /// Primeira posição ainda disponível.
  int get startOffset => _startOffset;

  /// Posição logo depois do último byte recebido (o "ao vivo").
  int get endOffset => _endOffset;

  /// Muda a cada [reset]. Leitores antigos usam isso para saber que devem parar.
  int get generation => _generation;

  DateTime? get oldestTime => _marks.isEmpty ? null : _marks.first.at;
  DateTime? get latestTime => _marks.isEmpty ? null : _marks.last.at;

  /// Quanto tempo de áudio está guardado agora.
  Duration get bufferedDuration {
    final a = oldestTime, b = latestTime;
    return (a == null || b == null) ? Duration.zero : b.difference(a);
  }

  /// Acrescenta bytes recebidos da rádio.
  void append(Uint8List data) {
    if (_disposed || data.isEmpty) return;
    final now = _clock();
    if (_marks.isEmpty || now.difference(_marks.last.at) >= const Duration(milliseconds: 500)) {
      _marks.add(_Mark(_endOffset, now));
    }
    var i = 0;
    while (i < data.length) {
      final room = segmentSize - _current.length;
      final n = room < data.length - i ? room : data.length - i;
      _current.add(Uint8List.sublistView(data, i, i + n));
      i += n;
      _endOffset += n;
      _currentLastAt = now;
      if (_current.length >= segmentSize) _flushCurrent();
    }
    _prune();
    _signal();
  }

  void _flushCurrent() {
    final bytes = _current.takeBytes();
    final file = File('${directory.path}/seg_${_generation}_${_segmentCounter++}.bin');
    file.writeAsBytesSync(bytes, flush: false);
    _segments.add(_Segment(_currentStart, bytes.length, file, _currentLastAt ?? _clock()));
    _currentStart += bytes.length;
    _current = BytesBuilder(copy: true);
  }

  void _prune() {
    final limit = _clock().subtract(window);
    while (_segments.isNotEmpty && _segments.first.lastAt.isBefore(limit)) {
      final s = _segments.removeAt(0);
      _deleteQuietly(s.file);
      _startOffset = s.start + s.length;
    }
    while (_marks.length > 1 && _marks[1].offset <= _startOffset) {
      _marks.removeAt(0);
    }
    if (_marks.isNotEmpty && _marks.first.offset < _startOffset) {
      _marks[0] = _Mark(_startOffset, _marks.first.at);
    }
  }

  /// Lê até [max] bytes a partir de [offset]. Se o offset já foi descartado,
  /// lê a partir do mais antigo disponível. Devolve vazio se ainda não chegou nada.
  ({int offset, Uint8List bytes}) read(int offset, int max) {
    var pos = offset < _startOffset ? _startOffset : offset;
    if (pos >= _endOffset) return (offset: pos, bytes: Uint8List(0));

    for (final s in _segments) {
      if (pos >= s.start && pos < s.start + s.length) {
        final n = _min(max, s.start + s.length - pos);
        final raf = s.file.openSync();
        try {
          raf.setPositionSync(pos - s.start);
          return (offset: pos, bytes: raf.readSync(n));
        } finally {
          raf.closeSync();
        }
      }
    }
    // Está no segmento que ainda está em memória.
    final mem = _current.toBytes();
    final from = pos - _currentStart;
    final n = _min(max, mem.length - from);
    return (offset: pos, bytes: Uint8List.sublistView(mem, from, from + n));
  }

  /// Os últimos [n] bytes gravados (menos, se ainda não houver tantos).
  Uint8List tail(int n) {
    final out = BytesBuilder(copy: true);
    var pos = _endOffset - n < _startOffset ? _startOffset : _endOffset - n;
    while (pos < _endOffset) {
      final r = read(pos, _endOffset - pos);
      if (r.bytes.isEmpty) break;
      out.add(r.bytes);
      pos = r.offset + r.bytes.length;
    }
    return out.takeBytes();
  }

  /// Espera chegar mais áudio (ou estoura em [timeout]).
  Future<void> waitForData({Duration timeout = const Duration(seconds: 2)}) {
    return _dataSignal.future.timeout(timeout, onTimeout: () {});
  }

  /// Horário em que o byte [offset] foi recebido.
  DateTime? timeAt(int offset) {
    if (_marks.isEmpty) return null;
    var lo = 0, hi = _marks.length - 1, best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_marks[mid].offset <= offset) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return _marks[best].at;
  }

  /// Posição do primeiro byte recebido em [time] ou depois.
  int offsetAt(DateTime time) {
    for (final m in _marks) {
      if (!m.at.isBefore(time)) return m.offset;
    }
    return _endOffset;
  }

  /// Descarta tudo (troca de rádio ou de formato). As posições continuam crescendo.
  void reset() {
    for (final s in _segments) {
      _deleteQuietly(s.file);
    }
    _segments.clear();
    _marks.clear();
    _current = BytesBuilder(copy: true);
    _startOffset = _endOffset;
    _currentStart = _endOffset;
    _generation++;
    _signal();
  }

  void dispose() {
    reset();
    _disposed = true;
  }

  void _signal() {
    if (!_dataSignal.isCompleted) _dataSignal.complete();
    _dataSignal = Completer<void>();
  }

  static int _min(int a, int b) => a < b ? a : b;

  static void _deleteQuietly(File f) {
    try {
      f.deleteSync();
    } catch (_) {}
  }
}

class _Segment {
  _Segment(this.start, this.length, this.file, this.lastAt);
  final int start;
  final int length;
  final File file;
  final DateTime lastAt;
}

class _Mark {
  _Mark(this.offset, this.at);
  final int offset;
  final DateTime at;
}
