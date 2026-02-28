import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'indexer_settings.dart';
import 'search_result.dart';
import 'search_service.dart';

/// Provides a [SearchService] that respects current [IndexerSettings].
final searchServiceProvider = Provider<SearchService>((ref) {
  final settings = ref.watch(indexerSettingsProvider);
  return TorrentSearchService(settings: settings);
});

/// Fetches search results for a given query string.
///
/// Usage:
/// ```dart
/// final results = ref.watch(searchResultsProvider('pink floyd'));
/// ```
final searchResultsProvider =
    FutureProvider.family<List<SearchResult>, String>((ref, query) async {
  final service = ref.watch(searchServiceProvider);
  return service.search(query);
});
