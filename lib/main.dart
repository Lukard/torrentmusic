import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player/audio_handler.dart';
import 'player/audio_player_service.dart';
import 'player/player_provider.dart';
import 'search/indexer_settings.dart';
import 'ui/screens/home_shell.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final playerService = AudioPlayerService();

  await AudioService.init(
    builder: () => TorrentMusicAudioHandler(playerService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.torrentmusic.player.channel',
      androidNotificationChannelName: 'TorrentMusic',
      androidNotificationOngoing: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(playerService),
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
