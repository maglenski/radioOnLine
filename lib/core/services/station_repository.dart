import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';

/// Guarda as rádios favoritas e a última tocada no próprio celular.
class StationRepository extends ChangeNotifier {
  static const _favoritesKey = 'favorites_v1';
  static const _lastKey = 'last_station_v1';

  late SharedPreferences _prefs;
  List<Station> _favorites = [];

  List<Station> get favorites => List.unmodifiable(_favorites);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_favoritesKey);
    if (raw != null) {
      try {
        _favorites = (jsonDecode(raw) as List)
            .map((e) => Station.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _favorites = [];
      }
    }
    notifyListeners();
  }

  bool isFavorite(Station s) => _favorites.any((f) => f.id == s.id);

  Station? favoriteById(String id) {
    for (final f in _favorites) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<void> save(Station s) async {
    final i = _favorites.indexWhere((f) => f.id == s.id);
    if (i >= 0) {
      _favorites[i] = s;
    } else {
      _favorites.add(s);
    }
    await _persist();
  }

  Future<void> remove(Station s) async {
    _favorites.removeWhere((f) => f.id == s.id);
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final s = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, s);
    await _persist();
  }

  Station? get lastStation {
    final raw = _prefs.getString(_lastKey);
    if (raw == null) return null;
    try {
      return Station.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastStation(Station s) => _prefs.setString(_lastKey, jsonEncode(s.toJson()));

  Future<void> _persist() async {
    await _prefs.setString(_favoritesKey, jsonEncode(_favorites.map((f) => f.toJson()).toList()));
    notifyListeners();
  }
}
