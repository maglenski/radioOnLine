import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/station.dart';
import '../core/services/station_repository.dart';
import 'app.dart';
import 'station_actions.dart';
import 'station_editor.dart';
import 'widgets/station_art.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<StationRepository>();
    final favorites = repo.favorites;

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName, style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar rádio pelo endereço',
        onPressed: () => StationEditor.show(context),
        child: const Icon(Icons.add_link_rounded),
      ),
      body: favorites.isEmpty
          ? _Empty(onSearch: onSearch)
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: favorites.length,
              onReorderItem: repo.reorder,
              itemBuilder: (context, i) => _FavoriteTile(
                key: ValueKey(favorites[i].id),
                station: favorites[i],
              ),
            ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (station.details.isNotEmpty) station.details,
      if (station.fallbackUrl != null) 'com reserva',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: StationArt(url: station.faviconUrl),
      title: Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
      onTap: () => StationActions.play(context, station),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') StationEditor.show(context, station: station);
          if (v == 'remove') context.read<StationRepository>().remove(station);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar endereços')),
          PopupMenuItem(value: 'remove', child: Text('Remover das favoritas')),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio_rounded, size: 72, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma rádio favorita ainda',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Busque por nome ou gênero, ou adicione uma rádio colando o endereço do stream.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Buscar rádios'),
            ),
          ],
        ),
      ),
    );
  }
}
