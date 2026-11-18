import 'package:flutter/foundation.dart';

/// Diário de bordo do motor de áudio: os últimos eventos (conexão, reconexão,
/// pausa, erro do player...) com horário, para investigar um defeito que só
/// acontece na rua. Fica só na memória do app e some ao fechar.
class DiagLog {
  DiagLog._();

  static const maxEntries = 400;
  static final List<String> _entries = [];

  /// Muda a cada evento novo (a tela de diagnóstico escuta isto).
  static final revision = ValueNotifier<int>(0);

  static List<String> get entries => List.unmodifiable(_entries);

  static void add(String event) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    _entries.add('${two(t.hour)}:${two(t.minute)}:${two(t.second)}  $event');
    if (_entries.length > maxEntries) _entries.removeRange(0, _entries.length - maxEntries);
    revision.value++;
    debugPrint('diag: $event');
  }

  static void clear() {
    _entries.clear();
    revision.value++;
  }

  static String dump() => _entries.join('\n');
}
