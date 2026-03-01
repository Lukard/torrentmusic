import 'search_result.dart';

/// Stub for the Nyaa scraping indexer.
/// Full implementation is provided by a separate agent.
class NyaaIndexer {
  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'Nyaa';

  /// Stub search — returns empty list until fully implemented.
  Future<List<SearchResult>> search(String query) async => [];
}
