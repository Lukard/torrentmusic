import 'package:torrentmusic/search/search_result.dart';
import 'package:torrentmusic/search/search_service.dart';

/// Mock search service returning fixture data for integration tests.
class MockSearchService implements SearchService {
  /// If non-null, [search] will throw this error.
  Object? searchError;

  /// If true, [search] will return an empty list.
  bool returnEmpty = false;

  /// Delay to simulate network latency.
  Duration latency = const Duration(milliseconds: 100);

  /// Custom results to return. If null, uses default fixtures.
  List<SearchResult>? customResults;

  int _searchCallCount = 0;

  /// Number of times [search] has been called.
  int get searchCallCount => _searchCallCount;

  @override
  Future<List<SearchResult>> search(String query, {SearchType? type}) async {
    _searchCallCount++;
    await Future<void>.delayed(latency);

    if (searchError != null) {
      throw searchError!;
    }

    if (returnEmpty) {
      return [];
    }

    if (customResults != null) {
      return customResults!;
    }

    return _defaultResults(query);
  }

  /// Reset state between tests.
  void reset() {
    searchError = null;
    returnEmpty = false;
    customResults = null;
    _searchCallCount = 0;
    latency = const Duration(milliseconds: 100);
  }

  static List<SearchResult> _defaultResults(String query) {
    return [
      SearchResult(
        title: '$query - Track One',
        magnetUri:
            'magnet:?xt=urn:btih:aaaa1111bbbb2222cccc3333dddd4444eeee5555&dn=track1',
        seeds: 150,
        leeches: 20,
        sizeBytes: 8388608, // 8 MB
        source: '1337x',
        category: 'Music',
      ),
      SearchResult(
        title: '$query - Track Two (FLAC)',
        magnetUri:
            'magnet:?xt=urn:btih:bbbb2222cccc3333dddd4444eeee5555ffff6666&dn=track2',
        seeds: 85,
        leeches: 12,
        sizeBytes: 31457280, // 30 MB
        source: '1337x',
        category: 'Music',
      ),
      SearchResult(
        title: '$query - Track Three',
        magnetUri:
            'magnet:?xt=urn:btih:cccc3333dddd4444eeee5555ffff6666aaaa7777&dn=track3',
        seeds: 42,
        leeches: 5,
        sizeBytes: 5242880, // 5 MB
        source: '1337x',
        category: 'Music',
      ),
      SearchResult(
        title: '$query - Track Four (Live)',
        magnetUri:
            'magnet:?xt=urn:btih:dddd4444eeee5555ffff6666aaaa7777bbbb8888&dn=track4',
        seeds: 210,
        leeches: 30,
        sizeBytes: 10485760, // 10 MB
        source: '1337x',
        category: 'Music',
      ),
    ];
  }
}
