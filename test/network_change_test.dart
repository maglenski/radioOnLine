import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_online/audio/local_stream_server.dart';
import 'package:radio_online/audio/stream_relay.dart';
import 'package:radio_online/audio/timeshift_buffer.dart';
import 'package:radio_online/core/models/station.dart';

/// Byte "no ar" na posição [i] da programação. Não se repete em ciclos curtos,
/// para a emenda só casar no lugar certo.
int onAir(int i) => ((i * 2654435761) >> 11) & 0xFF;

/// Rádio falsa que se comporta como um Icecast numa troca de rede:
/// derruba o ouvinte depois de [dropAfter] bytes e, na reconexão, reenvia os
/// últimos [burst] bytes que já foram ao ar. [missedOnReconnect] simula o
/// tempo que o ouvinte ficou fora (programação que ele perdeu).
class RoamingRadio {
  RoamingRadio({required this.dropAfter, required this.burst, this.missedOnReconnect = 0});

  final int dropAfter;
  final int burst;
  final int missedOnReconnect;
  late HttpServer server;
  int connections = 0;
  int live = 0; // posição da programação

  String get url => 'http://127.0.0.1:${server.port}/stream';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final n = ++connections;
      if (n > 1) live += missedOnReconnect;
      final res = req.response..headers.set('content-type', 'audio/mpeg');
      var cursor = live - burst < 0 ? 0 : live - burst;
      var sent = 0;
      try {
        // Só a primeira conexão cai; as seguintes ficam estáveis.
        while (n > 1 || sent < dropAfter) {
          res.add(Uint8List.fromList(List.generate(1000, (k) => onAir(cursor + k))));
          cursor += 1000;
          sent += 1000;
          if (cursor > live) live = cursor;
          await res.flush();
          await Future.delayed(const Duration(milliseconds: 5));
        }
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
    dir = Directory.systemTemp.createTempSync('roam_test');
    buffer = TimeshiftBuffer(directory: dir, segmentSize: 4096);
  });

  tearDown(() {
    buffer.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<void> waitFor(bool Function() ok, {int seconds = 10}) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (!ok() && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  test('queda curta: emenda sem repetir nem pular áudio', () async {
    final radio = RoamingRadio(dropAfter: 20000, burst: 8000);
    await radio.start();
    final relay = StreamRelay(buffer);
    final breaks = <int>[];
    relay.discontinuities.listen(breaks.add);

    await relay.start(Station(id: 'x', name: 'Fake', streamUrl: radio.url));
    await waitFor(() => radio.connections >= 2 && buffer.endOffset > 40000);
    relay.stop();

    final data = buffer.tail(buffer.endOffset);
    expect(data.length, greaterThan(40000));
    for (var i = 0; i < data.length; i++) {
      expect(data[i], onAir(i), reason: 'áudio repetido ou pulado na posição $i');
    }
    expect(breaks, isEmpty);
    await radio.stop();
  });

  test('queda longa: avisa onde começa o áudio novo', () async {
    final radio = RoamingRadio(dropAfter: 20000, burst: 8000, missedOnReconnect: 50000);
    await radio.start();
    final relay = StreamRelay(buffer);
    final breaks = <int>[];
    relay.discontinuities.listen(breaks.add);

    await relay.start(Station(id: 'x', name: 'Fake', streamUrl: radio.url));
    await waitFor(() => breaks.isNotEmpty);
    await Future.delayed(const Duration(milliseconds: 200));
    relay.stop();

    expect(breaks, [20000]);
    final data = buffer.tail(buffer.endOffset);
    expect(data[19999], onAir(19999));
    // Depois da quebra vem a programação nova: 20000 + 50000 perdidos - 8000 de reenvio.
    expect(data[20000], onAir(62000));
    await radio.stop();
  });

  test('falta de rede não conta como falha do endereço (não troca de qualidade)', () async {
    // Porta fechada: toda tentativa falha ao conectar, como numa troca de WiFi.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final dead = 'http://127.0.0.1:${probe.port}/stream';
    await probe.close();
    final relay = StreamRelay(buffer);
    unawaited(relay
        .start(Station(id: 'x', name: 'Fake', streamUrl: dead, fallbackUrl: '$dead/low'))
        .catchError((_) {}));
    await Future.delayed(const Duration(seconds: 5));
    expect(relay.usingFallback.value, isFalse);
    relay.stop();
  });

  test('servidor local continua de onde o player parou quando ele refaz o pedido', () async {
    final server = LocalStreamServer(buffer, contentType: () => 'audio/mpeg');
    await server.start();
    buffer.append(Uint8List.fromList(List.generate(30000, onAir)));

    final client = HttpClient();
    final req = await client.getUrl(server.uriFor(5000));
    req.headers.set('Range', 'bytes=12000-');
    final res = await req.close();
    expect(res.statusCode, 206);
    final first = await res.first;
    expect(first[0], onAir(17000));
    client.close(force: true);
    await server.stop();

    expect(LocalStreamServer.parseRangeStart(null), 0);
    expect(LocalStreamServer.parseRangeStart('bytes=0-'), 0);
    expect(LocalStreamServer.parseRangeStart('bytes=345-'), 345);
  });

  test('player repete o pedido depois de travar: continua de onde parou, não volta', () async {
    // Cenário do registro de 18/11: o player abriu às 09:40, tocou 9 minutos,
    // a rede travou, e o player do Android pediu o mesmo endereço de novo.
    final server = LocalStreamServer(buffer, contentType: () => 'audio/mpeg');
    await server.start();
    buffer.append(Uint8List.fromList(List.generate(30000, onAir)));
    final uri = server.uriFor(0);

    Future<List<int>> readUntilStall(Uri u) async {
      final client = HttpClient();
      final res = await (await client.getUrl(u)).close();
      final got = <int>[];
      try {
        await for (final c in res.timeout(const Duration(milliseconds: 500))) {
          got.addAll(c);
        }
      } on TimeoutException {
        // rede travou: o player desiste da conexão
      }
      client.close(force: true);
      return got;
    }

    final first = await readUntilStall(uri);
    expect(first.length, 30000);

    // A rádio volta uns segundos depois e chega mais áudio; o player pede o
    // mesmo endereço, sem dizer de onde continuar.
    await Future.delayed(const Duration(milliseconds: 300));
    buffer.append(Uint8List.fromList(List.generate(5000, (i) => onAir(30000 + i))));
    final second = await readUntilStall(uri);
    expect(second.length, 5000, reason: 'recomeçou do ponto em que o player foi aberto');
    expect(second.first, onAir(30000));
    await server.stop();
  });

  test('emendador desiste e devolve tudo quando não acha a emenda', () {
    final s = StreamSplicer(Uint8List.fromList(List.filled(64, 7)), maxBytes: 3000);
    expect(s.add(Uint8List.fromList(List.generate(1500, onAir))), isNull);
    final out = s.add(Uint8List.fromList(List.generate(1500, (i) => onAir(1500 + i))));
    expect(s.matched, isFalse);
    expect(out!.length, 3000);
  });
}
