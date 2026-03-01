import 'search_result.dart';

/// Stub for the Bitsearch API indexer.
/// Full implementation is provided by a separate agent.
class BitsearchIndexer {
  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'Bitsearch';

  /// Stub search — returns empty list until fully implemented.
  Future<List<SearchResult>> search(String query) async => [];
}
