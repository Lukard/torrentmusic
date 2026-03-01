import 'indexer_settings.dart';
import 'leet_indexer.dart';
import 'pirate_bay_indexer.dart';
import 'search_result.dart';

/// Interface for searching torrent indexers for music content.
abstract class SearchService {
  /// Search for music torrents matching [query].
  ///
  /// An optional [type] hint can be provided to narrow results.
  Future<List<SearchResult>> search(String query, {SearchType? type});
}

/// Concrete [SearchService] that aggregates results from multiple torrent
/// indexers, deduplicates them, and filters for audio content.
class TorrentSearchService implements SearchService {
  /// Creates a [TorrentSearchService].
  ///
  /// When [settings] is provided, enabled indexers are determined from it.
  /// Optional [leetIndexer] and [pirateBayIndexer] can be injected for testing.
  TorrentSearchService({
    IndexerSettings? settings,
    LeetIndexer? leetIndexer,
    PirateBayIndexer? pirateBayIndexer,
  })  : _settings = settings ?? const IndexerSettings(),
        _leetIndexer = leetIndexer,
        _pirateBayIndexer = pirateBayIndexer;

  final IndexerSettings _settings;
  final LeetIndexer? _leetIndexer;
  final PirateBayIndexer? _pirateBayIndexer;

  @override
  Future<List<SearchResult>> search(String query, {SearchType? type}) async {
    final futures = <Future<List<SearchResult>>>[];

    if (_settings.leetEnabled) {
      final indexer =
          _leetIndexer ?? LeetIndexer(mirrors: _settings.leetMirrors);
      futures.add(_safeSearch(indexer.search(query), LeetIndexer.sourceName));
    }

    if (_settings.pirateBayEnabled) {
      final indexer = _pirateBayIndexer ?? PirateBayIndexer();
      futures.add(
        _safeSearch(indexer.search(query), PirateBayIndexer.sourceName),
      );
    }

    if (futures.isEmpty) {
      throw StateError(
        'No indexers enabled. Enable at least one in Settings.',
      );
    }

    final results = await Future.wait(futures);
    final allResults = results.expand((r) => r).toList();

    // If every indexer returned empty, check if it's because they all failed.
    if (allResults.isEmpty && _indexerErrors.isNotEmpty) {
      final sources = _indexerErrors.join(', ');
      _indexerErrors.clear();
      throw StateError('Search failed — all indexers errored ($sources).');
    }
    _indexerErrors.clear();

    final filtered = allResults.where(isAudioContent).toList();
    final deduped = _deduplicate(filtered);

    // Sort by seeds descending.
    deduped.sort((a, b) => b.seeds.compareTo(a.seeds));

    return deduped;
  }

  final List<String> _indexerErrors = [];

  /// Wraps an indexer search so a single failure doesn't kill all results.
  Future<List<SearchResult>> _safeSearch(
    Future<List<SearchResult>> search,
    String sourceName,
  ) async {
    try {
      return await search;
    } catch (e) {
      _indexerErrors.add(sourceName);
      return [];
    }
  }

  /// Returns `true` when [result] looks like audio rather than video.
  ///
  /// The 1337x Music category already pre-filters, but video encodes
  /// occasionally slip through. This acts as a safety net.
  static bool isAudioContent(SearchResult result) {
    final lower = result.title.toLowerCase();
    const videoIndicators = [
      'x264',
      'x265',
      'h264',
      'h265',
      'hevc',
      'bluray',
      'brrip',
      'webrip',
      'hdtv',
      'dvdrip',
      '1080p',
      '720p',
      '2160p',
      '.mkv',
      '.avi',
      '.mp4',
      '.wmv',
    ];
    return !videoIndicators.any(lower.contains);
  }

  /// Deduplicates results by normalized title similarity.
  ///
  /// When two results have very similar titles, the one with more seeds wins.
  static List<SearchResult> _deduplicate(List<SearchResult> results) {
    final seen = <String, SearchResult>{};
    for (final result in results) {
      final key = _normalizeTitle(result.title);
      final existing = seen[key];
      if (existing == null || result.seeds > existing.seeds) {
        seen[key] = result;
      }
    }
    return seen.values.toList();
  }

  /// Normalizes a title for deduplication comparison.
  static String _normalizeTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }
}
