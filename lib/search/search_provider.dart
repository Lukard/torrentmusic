import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_result.dart';
import 'search_service.dart';

/// Provides the singleton [SearchService] instance.
final searchServiceProvider = Provider<SearchService>((ref) {
  return TorrentSearchService();
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
