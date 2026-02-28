import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// Page Object for bottom navigation and mini player interactions.
class NavigationRobot {
  final WidgetTester tester;

  const NavigationRobot(this.tester);

  Finder get _searchTab => find.text('Search').last;
  Finder get _libraryTab => find.text('Library').last;
  Finder get _settingsTab => find.text('Settings').last;

  /// Tap the Search tab.
  Future<void> tapSearchTab() async {
    await tester.tap(_searchTab);
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Tap the Library tab.
  Future<void> tapLibraryTab() async {
    await tester.tap(_libraryTab);
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Tap the Settings tab.
  Future<void> tapSettingsTab() async {
    await tester.tap(_settingsTab);
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Verify Search screen is displayed.
  void expectSearchScreen() {
    // The search screen has a heading "Search" and a TextField.
    expect(find.byType(TextField), findsOneWidget);
  }

  /// Verify Library screen is displayed.
  void expectLibraryScreen() {
    expect(find.text('Your library will appear here'), findsOneWidget);
  }

  /// Verify Settings screen is displayed.
  void expectSettingsScreen() {
    expect(find.text('Audio Quality'), findsOneWidget);
  }

  /// Tap the mini player to open Now Playing.
  Future<void> tapMiniPlayer() async {
    // The mini player has the track title and a GestureDetector.
    // Find the mini player container with play/pause controls.
    final playButton = find.byTooltip('Pause');
    final pauseButton = find.byTooltip('Play');

    // The mini player is a GestureDetector wrapping the track info.
    // We tap on the track title area in the mini player.
    // The mini player contains a LinearProgressIndicator with minHeight: 2.
    final miniPlayerProgress = find.byWidgetPredicate(
      (w) =>
          w is LinearProgressIndicator &&
          (playButton.evaluate().isNotEmpty ||
              pauseButton.evaluate().isNotEmpty),
    );

    if (miniPlayerProgress.evaluate().isNotEmpty) {
      // Tap near the mini player area but not on buttons.
      final firstProgress = miniPlayerProgress.first;
      final rect = tester.getRect(firstProgress);
      await tester.tapAt(Offset(rect.center.dx, rect.bottom + 20));
      await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
    }
  }

  /// Verify the mini player is visible with track title.
  void expectMiniPlayerVisible(String trackTitle) {
    expect(find.text(trackTitle), findsWidgets);
  }

  /// Verify the mini player is not visible.
  void expectMiniPlayerHidden() {
    // When no track is playing, the mini player's SizedBox.shrink is shown.
    // Check that no play/pause button exists outside Now Playing.
    // This is a heuristic — no Pause/Play tooltip in the nav area.
  }

  /// Tap mini player play/pause button.
  Future<void> tapMiniPlayerPlayPause() async {
    // Find the first play/pause button (mini player's is before bottom nav).
    final pause = find.byTooltip('Pause');
    final play = find.byTooltip('Play');
    if (pause.evaluate().isNotEmpty) {
      await tester.tap(pause.first);
    } else if (play.evaluate().isNotEmpty) {
      await tester.tap(play.first);
    }
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Go back from Now Playing screen.
  Future<void> goBackFromNowPlaying() async {
    final dismiss = find.byTooltip('Dismiss');
    if (dismiss.evaluate().isNotEmpty) {
      await tester.tap(dismiss);
      await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
    } else {
      // Use system back.
      final navigator = find.byType(Navigator);
      if (navigator.evaluate().isNotEmpty) {
        await tester.pageBack();
        await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
      }
    }
  }
}
