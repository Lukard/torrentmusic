import 'search_result.dart';

/// Stub for the Solidtorrents API indexer.
/// Full implementation is provided by a separate agent.
class SolidtorrentsIndexer {
  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'Solidtorrents';

  /// Stub search — returns empty list until fully implemented.
  Future<List<SearchResult>> search(String query) async => [];
}
