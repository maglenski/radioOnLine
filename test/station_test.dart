import 'package:flutter_test/flutter_test.dart';
import 'package:radio_online/core/models/station.dart';
import 'package:radio_online/core/services/artwork_service.dart';

void main() {
  test('converte item do Radio Browser preferindo url_resolved', () {
    final s = Station.fromRadioBrowser({
      'stationuuid': 'abc',
      'name': '  Rádio Teste ',
      'url': 'http://x/list.pls',
      'url_resolved': 'http://x/stream',
      'favicon': '',
      'countrycode': 'BR',
      'codec': 'MP3',
      'bitrate': 128,
      'tags': 'rock, classic rock,,80s',
    });
    expect(s.name, 'Rádio Teste');
    expect(s.streamUrl, 'http://x/stream');
    expect(s.faviconUrl, isNull);
    expect(s.tags, ['rock', 'classic rock', '80s']);
    expect(s.details, 'BR · MP3 · 128 kbps');
  });

  test('ida e volta em JSON preserva o endereço reserva', () {
    const s = Station(id: '1', name: 'A', streamUrl: 'http://a', fallbackUrl: 'http://b', manual: true);
    final back = Station.fromJson(s.toJson());
    expect(back.fallbackUrl, 'http://b');
    expect(back.manual, isTrue);
    expect(back.copyWith(clearFallback: true).fallbackUrl, isNull);
  });

  test('só busca capa quando o título parece "Artista - Música"', () {
    expect(ArtworkService.cleanTitle('Interpol - Evil (Remastered)'), 'Interpol - Evil');
    expect(ArtworkService.cleanTitle('Spoon Radio'), isNull);
    expect(ArtworkService.cleanTitle(''), isNull);
  });
}
