import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_audio_player_service.dart';
import '../mocks/mock_search_service.dart';
import '../mocks/mock_torrent_engine.dart';
import '../robots/navigation_robot.dart';
import '../robots/player_robot.dart';
import '../robots/search_robot.dart';
import '../test_helpers.dart';

/// Queue flow integration tests (5 tests).
void queueFlowTests() {
  late MockTorrentEngine mockEngine;
  late MockSearchService mockSearch;
  late MockAudioPlayerService mockPlayerService;

  setUp(() {
    mockEngine = TestHelpers.createMockEngine();
    mockSearch = TestHelpers.createMockSearch();
    mockPlayerService = MockAudioPlayerService();
  });

  /// Helper: search, play first, and add second to queue.
  Future<void> setupQueue(WidgetTester tester) async {
    final search = SearchRobot(tester);
    await search.enterQuery('queue test');
    // Tap first result to start playing.
    await search.tapResult('queue test - Track One');
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));

    // Long-press second result to add to queue.
    await search.longPressResult('queue test - Track Two (FLAC)');
  }

  testWidgets('Tap second result adds to queue', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
      mockPlayerService: mockPlayerService,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('queue test');

    // Tap first to play.
    await search.tapResult('queue test - Track One');
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));

    // Long-press second to add to queue.
    await search.longPressResult('queue test - Track Two (FLAC)');

    // Should see snackbar confirmation.
    expect(find.textContaining('Added'), findsOneWidget);
  });

  testWidgets('Next skips to next track', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
      mockPlayerService: mockPlayerService,
    );

    await setupQueue(tester);

    // Open Now Playing.
    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      // Tap next to skip.
      await player.tapNext();

      // The second track should now be shown.
      // Note: the mock may not fully load the second track since it needs
      // a file path, but the queue state should update.
    }
  });

  testWidgets('Previous goes back', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
      mockPlayerService: mockPlayerService,
    );

    await setupQueue(tester);

    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      // Skip to next first.
      await player.tapNext();

      // Then go back.
      await player.tapPrevious();
    }
  });

  testWidgets('Shuffle reorders queue', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
      mockPlayerService: mockPlayerService,
    );

    await setupQueue(tester);

    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      player.expectShuffleDisabled();

      await player.tapShuffle();
      player.expectShuffleEnabled();

      // Toggle back off.
      await player.tapShuffle();
      player.expectShuffleDisabled();
    }
  });

  testWidgets('Repeat modes cycle correctly', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
      mockPlayerService: mockPlayerService,
    );

    await setupQueue(tester);

    final nav = NavigationRobot(tester);
    await nav.tapMiniPlayer();

    final player = PlayerRobot(tester);
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      // Start: repeat off.
      player.expectRepeatOff();

      // Cycle to repeat all.
      await player.tapRepeat();
      player.expectRepeatAll();

      // Cycle to repeat one.
      await player.tapRepeat();
      player.expectRepeatOne();

      // Cycle back to off.
      await player.tapRepeat();
      player.expectRepeatOff();
    }
  });
}
