import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrentmusic/core/core_providers.dart';
import 'package:torrentmusic/main.dart';
import 'package:torrentmusic/player/audio_player_service.dart';
import 'package:torrentmusic/player/player_provider.dart';
import 'package:torrentmusic/search/search_provider.dart';

import 'mocks/mock_search_service.dart';
import 'mocks/mock_torrent_engine.dart';

/// Shared test fixtures and helper functions.
class TestHelpers {
  TestHelpers._();

  /// Pump the full app with mock overrides injected via Riverpod.
  static Future<void> pumpApp(
    WidgetTester tester, {
    required MockTorrentEngine mockEngine,
    required MockSearchService mockSearch,
    AudioPlayerService? mockPlayerService,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentEngineProvider.overrideWithValue(mockEngine),
          searchServiceProvider.overrideWithValue(mockSearch),
          if (mockPlayerService != null)
            audioPlayerServiceProvider.overrideWithValue(mockPlayerService),
        ],
        child: const TorrentMusicApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Create default mock instances.
  static MockTorrentEngine createMockEngine() => MockTorrentEngine();
  static MockSearchService createMockSearch() => MockSearchService();
}
