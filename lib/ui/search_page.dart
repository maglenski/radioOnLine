import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/station.dart';
import '../core/services/radio_browser_client.dart';
import '../core/services/station_repository.dart';
import 'app.dart';
import 'station_actions.dart';
import 'widgets/station_art.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _suggestions = ['rock', 'classic rock', 'pop', 'jazz', 'mpb', 'blues', 'metal', 'news'];

  final _controller = TextEditingController();
  List<Station> _results = [];
  bool _loading = false;
  bool _onlyBrazil = false;
  String? _error;
  int _searchId = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    term = term.trim();
    if (term.isEmpty) return;
    _controller.text = term;
    FocusScope.of(context).unfocus();
    final id = ++_searchId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context
          .read<RadioBrowserClient>()
          .search(term, countryCode: _onlyBrazil ? 'BR' : null);
      if (id != _searchId) return;
      setState(() => _results = r);
    } catch (e) {
      if (id != _searchId) return;
      setState(() => _error = 'Não consegui consultar o catálogo agora. Tente de novo.');
    } finally {
      if (id == _searchId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<StationRepository>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchBar(
            controller: _controller,
            hintText: 'Nome da rádio ou gênero',
            leading: const Icon(Icons.search_rounded),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
            elevation: const WidgetStatePropertyAll(0),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: const Text('Só Brasil'),
                  selected: _onlyBrazil,
                  onSelected: (v) {
                    setState(() => _onlyBrazil = v);
                    if (_controller.text.isNotEmpty) _search(_controller.text);
                  },
                ),
              ),
              for (final s in _suggestions)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(label: Text(s), onPressed: () => _search(s)),
                ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textMuted)))
              : _results.isEmpty
                  ? const Center(
                      child: Text(
                        'Catálogo aberto Radio Browser\ncom milhares de rádios do mundo todo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final s = _results[i];
                        final fav = repo.isFavorite(s);
                        return ListTile(
                          leading: StationArt(url: s.faviconUrl),
                          title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            [s.details, if (s.tags.isNotEmpty) s.tags.take(3).join(', ')]
                                .where((t) => t.isNotEmpty)
                                .join('\n'),
                            maxLines: 2,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          onTap: () => StationActions.play(context, s),
                          trailing: IconButton(
                            tooltip: fav ? 'Remover das favoritas' : 'Favoritar',
                            icon: Icon(
                              fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: fav ? AppColors.accent : null,
                            ),
                            onPressed: () => StationActions.toggleFavorite(context, s),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
