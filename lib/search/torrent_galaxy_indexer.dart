import 'search_result.dart';

/// Stub for the TorrentGalaxy scraping indexer.
/// Full implementation is provided by a separate agent.
class TorrentGalaxyIndexer {
  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'TorrentGalaxy';

  /// Stub search — returns empty list until fully implemented.
  Future<List<SearchResult>> search(String query) async => [];
}
