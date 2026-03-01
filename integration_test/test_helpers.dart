import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torrentmusic/core/core_providers.dart';
import 'package:torrentmusic/main.dart';
import 'package:torrentmusic/player/audio_player_service.dart';
import 'package:torrentmusic/player/player_provider.dart';
import 'package:torrentmusic/search/indexer_settings.dart';
import 'package:torrentmusic/search/search_provider.dart';

import 'mocks/mock_search_service.dart';
import 'mocks/mock_torrent_engine.dart';

class TestHelpers {
  TestHelpers._();

  static Future<void> pumpApp(
    WidgetTester tester, {
    required MockTorrentEngine mockEngine,
    required MockSearchService mockSearch,
    AudioPlayerService? mockPlayerService,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentEngineProvider.overrideWithValue(mockEngine),
          searchServiceProvider.overrideWithValue(mockSearch),
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (mockPlayerService != null)
            audioPlayerServiceProvider.overrideWithValue(mockPlayerService),
        ],
        child: const TorrentMusicApp(),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 2));
  }

  static Future<void> pumpFor(
    WidgetTester tester,
    Duration duration,
  ) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  static Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  static MockTorrentEngine createMockEngine() => MockTorrentEngine();
  static MockSearchService createMockSearch() => MockSearchService();
}
