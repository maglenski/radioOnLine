import 'dart:convert';

import 'package:http/http.dart' as http;

/// Procura a capa do álbum pelo título "Artista - Música" na busca pública do iTunes.
/// Sem chave de API. Se não achar, o app mostra o ícone da rádio.
class ArtworkService {
  ArtworkService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  final _cache = <String, String?>{};

  Future<String?> find(String streamTitle) async {
    final term = cleanTitle(streamTitle);
    if (term == null) return null;
    if (_cache.containsKey(term)) return _cache[term];
    String? url;
    try {
      final r = await _http
          .get(Uri.https('itunes.apple.com', '/search', {
            'term': term,
            'entity': 'song',
            'limit': '1',
          }))
          .timeout(const Duration(seconds: 6));
      final results = (jsonDecode(r.body) as Map)['results'] as List;
      if (results.isNotEmpty) {
        url = ((results.first as Map)['artworkUrl100'] as String?)
            ?.replaceAll('100x100bb', '600x600bb');
      }
    } catch (_) {}
    if (_cache.length > 200) _cache.clear();
    _cache[term] = url;
    return url;
  }

  /// Só vale buscar se parecer "Artista - Música"; vinhetas e propaganda ficam de fora.
  static String? cleanTitle(String raw) {
    final t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!t.contains(' - ') || t.length < 5) return null;
    return t.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
  }
}
