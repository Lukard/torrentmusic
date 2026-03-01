import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'search/indexer_settings.dart';
import 'ui/screens/home_shell.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TorrentMusicApp(),
    ),
  );
}

class TorrentMusicApp extends StatelessWidget {
  const TorrentMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TorrentMusic',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const HomeShell(),
    );
  }
}
