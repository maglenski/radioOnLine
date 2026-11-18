import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/station.dart';

/// Cliente do catálogo aberto Radio Browser (https://www.radio-browser.info).
///
/// O catálogo tem vários servidores espelho; a lista oficial vem de
/// `all.api.radio-browser.info`. Se um falhar, tenta o próximo.
class RadioBrowserClient {
  RadioBrowserClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  List<String>? _servers;
  int _current = 0;

  static const _fallbackServers = [
    'de1.api.radio-browser.info',
    'de2.api.radio-browser.info',
    'fi1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
  ];
  static const _headers = {'User-Agent': 'radioOnLine/1.0'};

  Future<List<String>> _loadServers() async {
    if (_servers != null) return _servers!;
    try {
      final r = await _http
          .get(Uri.https('all.api.radio-browser.info', '/json/servers'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      final list = (jsonDecode(r.body) as List)
          .map((e) => (e as Map)['name'] as String)
          .toSet()
          .toList()
        ..shuffle(Random());
      _servers = list.isEmpty ? [..._fallbackServers] : list;
    } catch (_) {
      _servers = [..._fallbackServers]..shuffle(Random());
    }
    return _servers!;
  }

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final servers = await _loadServers();
    Object? lastError;
    for (var i = 0; i < servers.length; i++) {
      final host = servers[(_current + i) % servers.length];
      try {
        final r = await _http
            .get(Uri.https(host, path, query), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) {
          _current = (_current + i) % servers.length;
          return jsonDecode(utf8.decode(r.bodyBytes));
        }
        lastError = 'HTTP ${r.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Catálogo de rádios indisponível ($lastError)');
  }

  /// Busca por nome e por gênero (tag) ao mesmo tempo e junta os resultados,
  /// mais ouvidas primeiro. Ex.: "rock" acha "Spoon Rock" e as rádios com tag rock.
  Future<List<Station>> search(String term, {String? countryCode, int limit = 60}) async {
    final base = {
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      'limit': '$limit',
      'countrycode': ?countryCode,
    };
    final results = await Future.wait([
      _get('/json/stations/search', {...base, 'name': term}),
      _get('/json/stations/search', {...base, 'tag': term.toLowerCase()}),
    ]);
    return _merge(results);
  }

  /// Rádios com o mesmo nome, para sugerir um endereço reserva de qualidade menor.
  Future<List<Station>> byExactName(String name) async {
    final r = await _get('/json/stations/byname/$name', {'hidebroken': 'true'});
    return _merge([r]).where((s) => s.name.toLowerCase() == name.toLowerCase()).toList();
  }

  /// Avisa o catálogo que a rádio foi tocada (regra de boa convivência da API).
  Future<void> registerClick(String stationId) async {
    try {
      await _get('/json/url/$stationId', const {});
    } catch (_) {}
  }

  static List<Station> _merge(List<dynamic> lists) {
    final seen = <String, Station>{};
    final clicks = <String, int>{};
    for (final list in lists) {
      for (final item in (list as List).cast<Map<String, dynamic>>()) {
        try {
          final s = Station.fromRadioBrowser(item);
          if (s.name.isEmpty) continue;
          seen.putIfAbsent(s.id, () => s);
          clicks[s.id] = (item['clickcount'] as int?) ?? 0;
        } catch (_) {}
      }
    }
    final out = seen.values.toList()
      ..sort((a, b) => (clicks[b.id] ?? 0).compareTo(clicks[a.id] ?? 0));
    return out;
  }
}
