import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_online/audio/timeshift_buffer.dart';

void main() {
  late Directory dir;
  late DateTime now;
  late TimeshiftBuffer buffer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ts_test');
    now = DateTime(2026, 11, 13, 10);
    buffer = TimeshiftBuffer(
      directory: dir,
      window: const Duration(minutes: 30),
      segmentSize: 1000,
      clock: () => now,
    );
  });

  tearDown(() {
    buffer.dispose();
    dir.deleteSync(recursive: true);
  });

  /// Simula [seconds] segundos de rádio a 100 bytes/s, com byte = posição % 256.
  void feed(int seconds) {
    for (var s = 0; s < seconds; s++) {
      final start = buffer.endOffset;
      buffer.append(Uint8List.fromList(List.generate(100, (i) => (start + i) % 256)));
      now = now.add(const Duration(seconds: 1));
    }
  }

  List<int> readAll(int from) {
    final out = <int>[];
    var pos = from;
    while (true) {
      final r = buffer.read(pos, 333);
      if (r.bytes.isEmpty) break;
      out.addAll(r.bytes);
      pos = r.offset + r.bytes.length;
    }
    return out;
  }

  test('lê de volta exatamente o que foi gravado, cruzando segmentos', () {
    feed(25); // 2500 bytes = 2 segmentos em disco + 500 em memória
    final data = readAll(0);
    expect(data.length, 2500);
    for (var i = 0; i < data.length; i++) {
      expect(data[i], i % 256);
    }
  });

  test('descarta o que passou de 30 minutos e mantém as posições absolutas', () {
    feed(40 * 60);
    expect(buffer.bufferedDuration.inMinutes, inInclusiveRange(29, 30));
    expect(buffer.startOffset, greaterThan(0));
    final r = buffer.read(0, 10); // posição já descartada: lê do mais antigo
    expect(r.offset, buffer.startOffset);
    expect(r.bytes.first, buffer.startOffset % 256);
    final files = dir.listSync().length;
    expect(files, lessThanOrEqualTo(30 * 60 * 100 ~/ 1000 + 2));
  });

  test('converte horário em posição e posição em horário', () {
    final t0 = now;
    feed(600); // 10 minutos
    final tenMinAgo = buffer.latestTime!.subtract(const Duration(minutes: 5));
    final offset = buffer.offsetAt(tenMinAgo);
    expect(offset, closeTo(300 * 100, 100));
    expect(buffer.timeAt(offset)!.difference(t0).inSeconds, closeTo(300, 1));
  });

  test('reset descarta tudo e muda a geração', () {
    feed(30);
    final gen = buffer.generation;
    buffer.reset();
    expect(buffer.generation, gen + 1);
    expect(buffer.read(0, 100).bytes, isEmpty);
    expect(dir.listSync(), isEmpty);
    feed(1);
    expect(buffer.read(buffer.startOffset, 1000).bytes.length, 100);
  });
}
