import 'search_result.dart';

/// Stub for the LimeTorrents scraping indexer.
/// Full implementation is provided by a separate agent.
class LimeTorrentsIndexer {
  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'LimeTorrents';

  /// Stub search — returns empty list until fully implemented.
  Future<List<SearchResult>> search(String query) async => [];
}
