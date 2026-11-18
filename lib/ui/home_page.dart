import 'package:flutter/material.dart';

import 'favorites_page.dart';
import 'search_page.dart';
import 'widgets/mini_player.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            FavoritesPage(onSearch: () => setState(() => _tab = 1)),
            const SearchPage(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'Favoritas',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Buscar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
