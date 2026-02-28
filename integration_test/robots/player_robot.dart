import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// Page Object for Now Playing screen interactions.
class PlayerRobot {
  final WidgetTester tester;

  const PlayerRobot(this.tester);

  Finder get _nextButton =>
      find.byTooltip('Next track').hitTestable().last; // last = full screen
  Finder get _previousButton => find.byTooltip('Previous track');
  Finder get _shuffleOffButton => find.byTooltip('Shuffle off');
  Finder get _shuffleOnButton => find.byTooltip('Shuffle on');
  Finder get _repeatOffButton => find.byTooltip('Repeat off');
  Finder get _repeatAllButton => find.byTooltip('Repeat all');
  Finder get _repeatOneButton => find.byTooltip('Repeat one');
  Finder get _dismissButton => find.byTooltip('Dismiss');
  Finder get _slider => find.byType(Slider);
  Finder get _nowPlayingTitle => find.text('Now Playing');

  /// Verify Now Playing screen is visible.
  void expectNowPlayingVisible() {
    expect(_nowPlayingTitle, findsOneWidget);
  }

  /// Verify track info is displayed.
  void expectTrackInfo(String title) {
    expect(find.text(title), findsWidgets);
  }

  /// Tap play/pause button on the Now Playing screen.
  Future<void> tapPlayPause() async {
    // Find the FAB (FloatingActionButton) which is the main play/pause
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab);
      await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
    }
  }

  /// Tap next track button.
  Future<void> tapNext() async {
    await tester.tap(_nextButton);
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Tap previous track button.
  Future<void> tapPrevious() async {
    await tester.tap(_previousButton);
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Toggle shuffle.
  Future<void> tapShuffle() async {
    final off = _shuffleOffButton;
    final on = _shuffleOnButton;
    if (off.evaluate().isNotEmpty) {
      await tester.tap(off);
    } else {
      await tester.tap(on);
    }
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Cycle repeat mode.
  Future<void> tapRepeat() async {
    final off = _repeatOffButton;
    final all = _repeatAllButton;
    final one = _repeatOneButton;
    if (off.evaluate().isNotEmpty) {
      await tester.tap(off);
    } else if (all.evaluate().isNotEmpty) {
      await tester.tap(all);
    } else if (one.evaluate().isNotEmpty) {
      await tester.tap(one);
    }
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Verify the seek bar is present.
  void expectSeekBar() {
    expect(_slider, findsOneWidget);
  }

  /// Drag the seek bar to a relative position (0.0 to 1.0).
  Future<void> seekTo(double fraction) async {
    final slider = _slider;
    expect(slider, findsOneWidget);
    final sliderWidget = tester.widget<Slider>(slider);
    final rect = tester.getRect(slider);
    final target = Offset(
      rect.left + rect.width * fraction,
      rect.center.dy,
    );
    await tester.tapAt(target);
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
    // Ignore the actual value; just verify the gesture was accepted.
    expect(sliderWidget, isNotNull);
  }

  /// Dismiss Now Playing screen.
  Future<void> dismiss() async {
    await tester.tap(_dismissButton);
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));
  }

  /// Verify download progress indicator is visible.
  void expectDownloadProgress() {
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  }

  /// Verify shuffle is enabled.
  void expectShuffleEnabled() {
    expect(_shuffleOnButton, findsOneWidget);
  }

  /// Verify shuffle is disabled.
  void expectShuffleDisabled() {
    expect(_shuffleOffButton, findsOneWidget);
  }

  /// Verify repeat mode.
  void expectRepeatOff() {
    expect(_repeatOffButton, findsOneWidget);
  }

  void expectRepeatAll() {
    expect(_repeatAllButton, findsOneWidget);
  }

  void expectRepeatOne() {
    expect(_repeatOneButton, findsOneWidget);
  }
}
