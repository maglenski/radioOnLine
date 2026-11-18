import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_online/audio/icy_demuxer.dart';

/// Monta um stream ICY: [metaInt] bytes de áudio + bloco de metadados, repetido.
Uint8List icyStream(List<int> audio, int metaInt, Map<int, String> titlesAtBlock) {
  final out = BytesBuilder();
  var block = 0;
  for (var i = 0; i < audio.length; i += metaInt) {
    out.add(audio.sublist(i, (i + metaInt).clamp(0, audio.length)));
    final title = titlesAtBlock[block++];
    if (title == null) {
      out.addByte(0);
    } else {
      final text = utf8.encode("StreamTitle='$title';");
      final len = (text.length / 16).ceil();
      out.addByte(len);
      out.add([...text, ...List.filled(len * 16 - text.length, 0)]);
    }
  }
  return out.toBytes();
}

void main() {
  final audio = List<int>.generate(1000, (i) => i % 251);

  test('separa áudio e título mesmo com pedaços de tamanho aleatório', () {
    final stream = icyStream(audio, 100, {2: 'Interpol - Evil', 7: 'Évanescence - Bring Me'});
    final demux = IcyDemuxer(100);
    final titles = <String>[];
    final out = BytesBuilder();
    var i = 0;
    for (final size in [1, 7, 99, 100, 3, 250, 13, 512, 5000]) {
      if (i >= stream.length) break;
      final end = (i + size).clamp(0, stream.length);
      out.add(demux.process(Uint8List.sublistView(stream, i, end), titles.add));
      i = end;
    }
    expect(out.toBytes(), audio);
    expect(titles, ['Interpol - Evil', 'Évanescence - Bring Me']);
  });

  test('sem icy-metaint devolve tudo como áudio', () {
    final demux = IcyDemuxer(null);
    final data = Uint8List.fromList(audio);
    expect(demux.process(data, (_) => fail('não devia ter título')), data);
  });

  test('título vazio é ignorado', () {
    expect(IcyDemuxer.parseStreamTitle(utf8.encode("StreamTitle='';")), isNull);
    expect(
      IcyDemuxer.parseStreamTitle(utf8.encode("StreamTitle='It's Alive - Ramones';StreamUrl='';")),
      "It's Alive - Ramones",
    );
  });

  test('aceita texto em latin1 (servidores antigos)', () {
    final raw = latin1.encode("StreamTitle='Legião Urbana - Tempo Perdido';");
    expect(IcyDemuxer.parseStreamTitle(raw), 'Legião Urbana - Tempo Perdido');
  });
}
