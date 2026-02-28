import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_search_service.dart';
import '../mocks/mock_torrent_engine.dart';
import '../robots/search_robot.dart';
import '../test_helpers.dart';

/// Search flow integration tests (6 tests).
void searchFlowTests() {
  late MockTorrentEngine mockEngine;
  late MockSearchService mockSearch;

  setUp(() {
    mockEngine = TestHelpers.createMockEngine();
    mockSearch = TestHelpers.createMockSearch();
  });

  testWidgets('Enter query shows results (mock 4 tracks)', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('pink floyd');

    search.expectResultsVisible([
      'pink floyd - Track One',
      'pink floyd - Track Two (FLAC)',
      'pink floyd - Track Three',
      'pink floyd - Track Four (Live)',
    ]);
  });

  testWidgets('Clear query clears results', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);

    // Enter a query.
    await search.enterQuery('test');
    search.expectResultsVisible(['test - Track One']);

    // Clear the query.
    await search.clearQuery();
    search.expectResultsCleared();
  });

  testWidgets('Loading spinner while searching', (tester) async {
    // Use a longer latency so we can catch the loading state.
    mockSearch.latency = const Duration(seconds: 2);

    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    // Enter text and submit.
    await tester.enterText(find.byType(TextField), 'slow query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    // Pump once to trigger the search without settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Loading spinner should be visible.
    final search = SearchRobot(tester);
    search.expectLoading();

    // Wait for search to complete.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    search.expectResultsVisible(['slow query - Track One']);
  });

  testWidgets('Empty results shows message', (tester) async {
    mockSearch.returnEmpty = true;

    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('nonexistent');

    search.expectEmptyResults('nonexistent');
  });

  testWidgets('Network error shows error + retry button', (tester) async {
    mockSearch.searchError = Exception('Network error: connection refused');

    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('failing query');

    search.expectError();

    // Now fix the error and retry.
    mockSearch.searchError = null;
    await search.tapRetry();

    // Should now show results.
    search.expectResultsVisible(['failing query - Track One']);
  });

  testWidgets('Results show title, artist, seeds, size', (tester) async {
    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('metadata test');

    // Verify titles.
    expect(find.text('metadata test - Track One'), findsOneWidget);

    // Verify source info.
    expect(find.textContaining('1337x'), findsWidgets);

    // Verify seeds are shown (the seed counts from fixtures).
    expect(find.text('150'), findsOneWidget);

    // Verify size is shown (8 MB for first track).
    expect(find.text('8.0 MB'), findsOneWidget);
  });
}
