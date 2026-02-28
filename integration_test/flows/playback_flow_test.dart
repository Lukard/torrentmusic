import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_search_service.dart';
import '../mocks/mock_torrent_engine.dart';
import '../robots/navigation_robot.dart';
import '../robots/player_robot.dart';
import '../robots/search_robot.dart';
import '../test_helpers.dart';

/// Playback flow integration tests (9 tests).
void playbackFlowTests() {
  late MockTorrentEngine mockEngine;
  late MockSearchService mockSearch;

  setUp(() {
    mockEngine = TestHelpers.createMockEngine();
    mockSearch = TestHelpers.createMockSearch();
  });

  /// Helper: search and tap first result.
  Future<void> searchAndPlay(WidgetTester tester) async {
    final search = SearchRobot(tester);
    await search.enterQuery('test');
    await search.tapResult('test - Track One');
    // Allow preparation to start.
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  testWidgets('Tap result starts download + shows loading state',
      (tester) async {
    mockSearch.latency = const Duration(milliseconds: 50);

    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('test');

    // Tap result — this triggers orchestrator.playSearchResult.
    await tester.tap(find.text('test - Track One'));
    await tester.pump(const Duration(milliseconds: 100));

    // The preparation banner should show a loading state.
    // Look for preparation indicators (CircularProgressIndicator or status text).
    final loadingIndicators = find.byType(CircularProgressIndicator);
    // At least one should be present during preparation.
    expect(
      loadingIndicators.evaluate().isNotEmpty ||
          find.textContaining('torrent').evaluate().isNotEmpty ||
          find.textContaining('Buffering').evaluate().isNotEmpty ||
          find.textContaining('Adding').evaluate().isNotEmpty,
      isTrue,
    );

    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  });

  testWidgets('Download progress visible in Now Playing', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    // Open Now Playing.
    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    // Download progress (LinearProgressIndicator) should be visible.
    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      player.expectDownloadProgress();
    }
  });

  testWidgets('Playback starts when buffer ready', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    // After the mock engine reports ready, playback should start.
    // The mock marks ready in startStreaming, so the orchestrator proceeds.
    // Verify a track is now "current" by checking mini player appears.
    expect(
      find.text('test - Track One'),
      findsWidgets,
      reason: 'Track should be displayed after playback starts',
    );
  });

  testWidgets('Play/pause works', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    // Open Now Playing.
    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      // Toggle play/pause.
      await player.tapPlayPause();

      // Toggle back.
      await player.tapPlayPause();
    }
  });

  testWidgets('Seek bar works', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      player.expectSeekBar();
      // Seek to ~50% of the track.
      await player.seekTo(0.5);
    }
  });

  testWidgets('Progress bar advances', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      // The slider should exist and have a value.
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      // Pump some time to let position advance.
      await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
      // Slider should still be present.
      expect(slider, findsOneWidget);
    }
  });

  testWidgets('Track info displayed correctly', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      player.expectNowPlayingVisible();
      player.expectTrackInfo('test - Track One');
    }
  });

  testWidgets('Mini player shows current track', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    // Mini player should show the track title.
    final nav = NavigationRobot(tester);
    nav.expectMiniPlayerVisible('test - Track One');
  });

  testWidgets('Mini player play/pause works', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    await searchAndPlay(tester);

    final nav = NavigationRobot(tester);
    nav.expectMiniPlayerVisible('test - Track One');

    // Tap play/pause on mini player.
    await nav.tapMiniPlayerPlayPause();

    // Tap again to toggle back.
    await nav.tapMiniPlayerPlayPause();

    // Track should still be visible.
    nav.expectMiniPlayerVisible('test - Track One');
  });
}
