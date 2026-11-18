import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_online/audio/local_stream_server.dart';
import 'package:radio_online/audio/stream_relay.dart';
import 'package:radio_online/audio/timeshift_buffer.dart';
import 'package:radio_online/core/models/station.dart';

/// Rádio falsa estilo Icecast: manda áudio com metadados ICY e
/// derruba a conexão depois de [dropAfterBytes] (simula a queda do WiFi).
class FakeRadio {
  FakeRadio({this.metaInt = 1000, this.dropAfterBytes});

  final int metaInt;
  final int? dropAfterBytes;
  late HttpServer server;
  int connections = 0;
  int _byte = 0;

  String get url => 'http://127.0.0.1:${server.port}/stream';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/list.pls') {
        req.response.headers.contentType = ContentType('audio', 'x-scpls');
        req.response.write('[playlist]\nFile1=$url\nLength1=-1\n');
        await req.response.close();
        return;
      }
      connections++;
      final res = req.response;
      res.headers.set('content-type', 'audio/mpeg');
      final wantsMeta = req.headers.value('icy-metadata') == '1';
      if (wantsMeta) res.headers.set('icy-metaint', '$metaInt');
      var sent = 0;
      var block = 0;
      try {
        while (dropAfterBytes == null || sent < dropAfterBytes!) {
          final audio = Uint8List.fromList(List.generate(metaInt, (_) => _byte++ % 256));
          res.add(audio);
          sent += metaInt;
          if (wantsMeta) {
            final text = utf8.encode("StreamTitle='Banda - Musica ${block++}';");
            final len = (text.length / 16).ceil();
            res.add([len, ...text, ...List.filled(len * 16 - text.length, 0)]);
          }
          await res.flush();
          await Future.delayed(const Duration(milliseconds: 5));
        }
      } catch (_) {}
      // Encerra o stream, como uma rádio que derruba o ouvinte.
      try {
        await res.close();
      } catch (_) {}
    });
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  late Directory dir;
  late TimeshiftBuffer buffer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('relay_test');
    buffer = TimeshiftBuffer(directory: dir, segmentSize: 4096);
  });

  tearDown(() {
    buffer.dispose();
    dir.deleteSync(recursive: true);
  });

  test('grava o áudio limpo (sem metadados) e entrega os títulos', () async {
    final radio = FakeRadio();
    await radio.start();
    final relay = StreamRelay(buffer);
    final titles = <String>[];
    relay.titles.listen(titles.add);

    await relay.start(Station(id: 'x', name: 'Fake', streamUrl: radio.url));
    await Future.delayed(const Duration(milliseconds: 300));
    relay.stop();

    final data = buffer.read(0, buffer.endOffset).bytes;
    expect(data.length, greaterThan(3000));
    for (var i = 0; i < data.length; i++) {
      expect(data[i], i % 256, reason: 'byte $i veio misturado com metadado');
    }
    expect(titles.first, 'Banda - Musica 0');
    await radio.stop();
  });

  test('reconecta sozinho quando a rádio derruba a conexão', () async {
    final radio = FakeRadio(dropAfterBytes: 5000);
    await radio.start();
    final relay = StreamRelay(buffer);

    await relay.start(Station(id: 'x', name: 'Fake', streamUrl: radio.url));
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (radio.connections < 3 && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    relay.stop();
    expect(radio.connections, greaterThanOrEqualTo(3));
    expect(buffer.endOffset, greaterThanOrEqualTo(10000));
    await radio.stop();
  });

  test('troca para o endereço reserva depois de quedas seguidas', () async {
    final bad = FakeRadio(dropAfterBytes: 1000);
    final good = FakeRadio();
    await bad.start();
    await good.start();
    final relay = StreamRelay(buffer);

    await relay.start(Station(id: 'x', name: 'Fake', streamUrl: bad.url, fallbackUrl: good.url));
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!relay.usingFallback.value && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    expect(relay.usingFallback.value, isTrue);
    await Future.delayed(const Duration(seconds: 2));
    expect(good.connections, greaterThanOrEqualTo(1));
    relay.stop();
    await bad.stop();
    await good.stop();
  });

  test('resolve playlist .pls', () async {
    final radio = FakeRadio();
    await radio.start();
    final relay = StreamRelay(buffer);
    await relay.start(Station(
      id: 'x',
      name: 'Fake',
      streamUrl: 'http://127.0.0.1:${radio.server.port}/list.pls',
    ));
    expect(buffer.endOffset, greaterThan(0));
    relay.stop();
    await radio.stop();
  });

  test('servidor local entrega o áudio a partir da posição pedida e segue ao vivo', () async {
    final radio = FakeRadio();
    await radio.start();
    final relay = StreamRelay(buffer);
    final server = LocalStreamServer(buffer, contentType: () => relay.contentType);
    await server.start();
    await relay.start(Station(id: 'x', name: 'Fake', streamUrl: radio.url));
    await Future.delayed(const Duration(milliseconds: 200));

    final from = buffer.endOffset ~/ 2;
    final client = HttpClient();
    final res = await (await client.getUrl(server.uriFor(from))).close();
    expect(res.headers.contentType?.mimeType, 'audio/mpeg');

    final target = buffer.endOffset - from + 20000;
    final got = <int>[];
    final done = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = res.listen((chunk) {
      got.addAll(chunk);
      // Pede mais do que havia gravado na hora do pedido: prova que segue o ao vivo.
      if (got.length > target && !done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(seconds: 5));
    await sub.cancel();
    client.close(force: true);

    for (var i = 0; i < 5000; i++) {
      expect(got[i], (from + i) % 256);
    }
    relay.stop();
    await server.stop();
    await radio.stop();
  });

  test('parsePlaylist pega o primeiro endereço', () {
    expect(StreamRelay.parsePlaylist('#EXTM3U\n#EXTINF:-1,Radio\nhttp://a.b/c\n'), 'http://a.b/c');
    expect(StreamRelay.parsePlaylist('[playlist]\nFile1=https://x.y/z\n'), 'https://x.y/z');
    expect(StreamRelay.parsePlaylist('nada'), isNull);
  });
}
