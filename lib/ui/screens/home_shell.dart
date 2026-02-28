import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_provider.dart';
import '../widgets/mini_player.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Navigation tab index.
final _tabIndexProvider = StateProvider<int>((ref) => 0);

/// Root shell — bottom nav + mini player + screen body.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _screens = <Widget>[
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(_tabIndexProvider);
    final hasTrack = ref.watch(playerProvider).currentTrack != null;

    return Scaffold(
      body: IndexedStack(index: tabIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTrack) MiniPlayer(onTap: () => _openNowPlaying(context)),
          NavigationBar(
            selectedIndex: tabIndex,
            onDestinationSelected: (i) {
              ref.read(_tabIndexProvider.notifier).state = i;
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
