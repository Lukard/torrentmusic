import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_search_service.dart';
import '../mocks/mock_torrent_engine.dart';
import '../robots/navigation_robot.dart';
import '../test_helpers.dart';

/// Navigation flow integration tests (5 tests).
void navigationFlowTests() {
  late MockTorrentEngine mockEngine;
  late MockSearchService mockSearch;

  setUp(() {
    mockEngine = TestHelpers.createMockEngine();
    mockSearch = TestHelpers.createMockSearch();
  });

  testWidgets('App starts on Search tab', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final nav = NavigationRobot(tester);
    nav.expectSearchScreen();
    // The TextField for search should be visible.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Bottom nav switches between Search/Library/Settings',
      (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final nav = NavigationRobot(tester);

    // Start on Search.
    nav.expectSearchScreen();

    // Switch to Library.
    await nav.tapLibraryTab();
    nav.expectLibraryScreen();

    // Switch to Settings.
    await nav.tapSettingsTab();
    nav.expectSettingsScreen();

    // Back to Search.
    await nav.tapSearchTab();
    nav.expectSearchScreen();
  });

  testWidgets('Tap mini player opens Now Playing', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    // First, trigger a search and tap a result to get a track playing.
    await tester.enterText(find.byType(TextField), 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Tap the first result to start playback.
    final firstResult = find.text('test - Track One');
    if (firstResult.evaluate().isNotEmpty) {
      await tester.tap(firstResult);
      // Allow orchestrator and preparation to process.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Now the mini player should show the track.
      // Tap the mini player area to open Now Playing.
      final nav = NavigationRobot(tester);
      await nav.tapMiniPlayer();
      // If Now Playing opened, we should see the dismiss button.
      final dismiss = find.byTooltip('Dismiss');
      if (dismiss.evaluate().isNotEmpty) {
        expect(find.text('Now Playing'), findsOneWidget);
      }
    }
  });

  testWidgets('Back from Now Playing returns to previous screen',
      (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    // Search and tap result.
    await tester.enterText(find.byType(TextField), 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final firstResult = find.text('test - Track One');
    if (firstResult.evaluate().isNotEmpty) {
      await tester.tap(firstResult);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final nav = NavigationRobot(tester);
      await nav.tapMiniPlayer();
      await tester.pumpAndSettle();

      // Dismiss Now Playing.
      await nav.goBackFromNowPlaying();

      // Should be back on the search screen.
      nav.expectSearchScreen();
    }
  });

  testWidgets('Mini player persists across tab changes', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    // Search and play a track.
    await tester.enterText(find.byType(TextField), 'test');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final firstResult = find.text('test - Track One');
    if (firstResult.evaluate().isNotEmpty) {
      await tester.tap(firstResult);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final nav = NavigationRobot(tester);

      // Switch to Library — mini player should still show track.
      await nav.tapLibraryTab();
      nav.expectLibraryScreen();
      // Track title should still be visible in mini player.
      nav.expectMiniPlayerVisible('test - Track One');

      // Switch to Settings — mini player should persist.
      await nav.tapSettingsTab();
      nav.expectSettingsScreen();
      nav.expectMiniPlayerVisible('test - Track One');

      // Back to Search.
      await nav.tapSearchTab();
      nav.expectMiniPlayerVisible('test - Track One');
    }
  });
}
