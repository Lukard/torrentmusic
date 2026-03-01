import 'search_result.dart';

/// Stub for the BTDig API indexer.
/// Full implementation is provided by a separate agent.
class BtdigIndexer {
  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'BTDig';

  /// Stub search — returns empty list until fully implemented.
  Future<List<SearchResult>> search(String query) async => [];
}
