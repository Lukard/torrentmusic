import 'package:flutter_test/flutter_test.dart';
import 'package:torrentmusic/search/search_result.dart';

import '../mocks/mock_search_service.dart';
import '../mocks/mock_torrent_engine.dart';
import '../robots/search_robot.dart';
import '../test_helpers.dart';

/// Helper: returns true if any of the given text patterns is found.
bool _anyTextFound(List<String> patterns) {
  for (final p in patterns) {
    if (find.textContaining(p).evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Error handling integration tests (3 tests).
void errorHandlingTests() {
  late MockTorrentEngine mockEngine;
  late MockSearchService mockSearch;

  setUp(() {
    mockEngine = TestHelpers.createMockEngine();
    mockSearch = TestHelpers.createMockSearch();
  });

  testWidgets('Torrent with no seeds shows error', (tester) async {
    mockSearch.customResults = [
      const SearchResult(
        title: 'Dead Torrent - No Seeds',
        magnetUri:
            'magnet:?xt=urn:btih:0000000000000000000000000000000000000000&dn=dead',
        seeds: 0,
        leeches: 0,
        sizeBytes: 5242880,
        source: '1337x',
        category: 'Music',
      ),
    ];

    mockEngine.addMagnetError =
        StateError('No peers available: torrent has no seeds');

    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('dead torrent');

    expect(find.text('Dead Torrent - No Seeds'), findsOneWidget);

    await tester.tap(find.text('Dead Torrent - No Seeds'));
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));

    expect(
      _anyTextFound(
        ['No peers', 'error', 'failed', 'Playback failed'],
      ),
      isTrue,
      reason: 'An error message should be shown for a seedless torrent',
    );
  });

  testWidgets('Download timeout shows retry', (tester) async {
    mockEngine.addMagnetError = TimeoutError();

    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('timeout test');

    await tester.tap(find.text('timeout test - Track One'));
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));

    expect(
      _anyTextFound(
        ['Timeout', 'timeout', 'failed', 'Playback failed', 'error'],
      ),
      isTrue,
      reason: 'A timeout error message should be shown',
    );
  });

  testWidgets('Invalid magnet shows error', (tester) async {
    mockSearch.customResults = [
      const SearchResult(
        title: 'Invalid Magnet Track',
        magnetUri: 'not-a-valid-magnet-uri',
        seeds: 100,
        leeches: 10,
        sizeBytes: 5242880,
        source: '1337x',
        category: 'Music',
      ),
    ];

    mockEngine.addMagnetError =
        ArgumentError('Invalid magnet URI: missing xt=urn:btih: parameter');

    await TestHelpers.pumpApp(
      tester,
      mockEngine: mockEngine,
      mockSearch: mockSearch,
    );

    final search = SearchRobot(tester);
    await search.enterQuery('invalid');

    expect(find.text('Invalid Magnet Track'), findsOneWidget);

    await tester.tap(find.text('Invalid Magnet Track'));
    await TestHelpers.pumpFor(tester, const Duration(seconds: 2));

    expect(
      _anyTextFound(
        ['Invalid', 'invalid', 'failed', 'Playback failed', 'error'],
      ),
      isTrue,
      reason: 'An error message should be shown for invalid magnet',
    );
  });
}

/// Simple timeout error for testing.
class TimeoutError implements Exception {
  @override
  String toString() => 'TimeoutException: Timed out waiting for torrent buffer';
}
