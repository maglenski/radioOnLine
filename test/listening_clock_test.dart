import 'package:flutter_test/flutter_test.dart';
import 'package:radio_online/audio/listening_clock.dart';

/// Simula o player informando a posição a cada 200 ms durante [seconds].
Duration play(ListeningClock c, Duration from, int seconds) {
  var p = from;
  for (var i = 0; i < seconds * 5; i++) {
    p += const Duration(milliseconds: 200);
    c.onPlayerPosition(p);
  }
  return p;
}

void main() {
  final t0 = DateTime(2026, 11, 18, 9, 40, 2);

  test('reprodução normal: o momento ouvido avança junto com o player', () {
    final c = ListeningClock()..open(t0)..ready();
    play(c, Duration.zero, 540);
    expect(c.heard, t0.add(const Duration(seconds: 540)));
  });

  test('player recomeça a contagem do zero (erro de rede): não volta nem congela', () {
    // Exatamente o registro de 18/11: 9 minutos tocando, queda, o player do
    // Android refaz o pedido e volta a contar do zero.
    final c = ListeningClock()..open(t0)..ready();
    play(c, Duration.zero, 540);
    c.onPlayerPosition(Duration.zero); // recomeçou
    play(c, Duration.zero, 50);
    expect(c.heard, t0.add(const Duration(seconds: 590)));
  });

  test('posições de antes da fonte abrir são ignoradas', () {
    final c = ListeningClock()..open(t0);
    c.onPlayerPosition(const Duration(minutes: 9)); // resto da fonte anterior
    c.ready();
    play(c, Duration.zero, 10);
    expect(c.heard, t0.add(const Duration(seconds: 10)));
  });

  test('player travado (sem rede): o momento ouvido fica parado', () {
    final c = ListeningClock()..open(t0)..ready();
    final p = play(c, Duration.zero, 30);
    for (var i = 0; i < 50; i++) {
      c.onPlayerPosition(p);
    }
    expect(c.heard, t0.add(const Duration(seconds: 30)));
  });

  test('salto grande para frente não é tratado como música tocada', () {
    final c = ListeningClock()..open(t0)..ready();
    play(c, Duration.zero, 10);
    c.onPlayerPosition(const Duration(minutes: 20));
    expect(c.heard, t0.add(const Duration(seconds: 10)));
  });
}
