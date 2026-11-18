import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/radio_audio_handler.dart';
import '../core/models/station.dart';
import '../core/services/radio_browser_client.dart';
import '../core/services/station_repository.dart';

/// Ações sobre rádios usadas em mais de uma tela.
class StationActions {
  static Future<void> play(BuildContext context, Station station) async {
    final repo = context.read<StationRepository>();
    final catalog = context.read<RadioBrowserClient>();
    final handler = context.read<RadioAudioHandler>();
    // Se for favorita, usa a versão salva (que pode ter endereço reserva).
    final s = repo.favoriteById(station.id) ?? station;
    await repo.setLastStation(s);
    if (!s.manual) catalog.registerClick(s.id);
    await handler.playStation(s);
  }

  /// Favorita e, se o catálogo tiver a mesma rádio com qualidade menor,
  /// já guarda esse endereço como reserva.
  static Future<void> toggleFavorite(BuildContext context, Station station) async {
    final repo = context.read<StationRepository>();
    final catalog = context.read<RadioBrowserClient>();
    if (repo.isFavorite(station)) {
      await repo.remove(station);
      return;
    }
    await repo.save(station);
    if (station.manual || station.fallbackUrl != null) return;
    try {
      final twins = await catalog.byExactName(station.name);
      final current = station.bitrate ?? 9999;
      final lower = twins
          .where((t) => t.id != station.id && t.bitrate != null && t.bitrate! < current)
          .toList()
        ..sort((a, b) => b.bitrate!.compareTo(a.bitrate!));
      if (lower.isNotEmpty && repo.isFavorite(station)) {
        await repo.save(station.copyWith(fallbackUrl: lower.first.streamUrl));
      }
    } catch (_) {}
  }
}
