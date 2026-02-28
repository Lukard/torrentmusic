import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/screens/home_shell.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TorrentMusicApp()));
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
