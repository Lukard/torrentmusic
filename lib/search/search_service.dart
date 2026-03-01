import 'bitsearch_indexer.dart';
import 'btdig_indexer.dart';
import 'indexer_settings.dart';
import 'leet_indexer.dart';
import 'limetorrents_indexer.dart';
import 'nyaa_indexer.dart';
import 'pirate_bay_indexer.dart';
import 'search_result.dart';
import 'solidtorrents_indexer.dart';
import 'torrent_galaxy_indexer.dart';

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
  /// Optional indexer instances can be injected for testing.
  TorrentSearchService({
    IndexerSettings? settings,
    LeetIndexer? leetIndexer,
    PirateBayIndexer? pirateBayIndexer,
    SolidtorrentsIndexer? solidtorrentsIndexer,
    BitsearchIndexer? bitsearchIndexer,
    BtdigIndexer? btdigIndexer,
    NyaaIndexer? nyaaIndexer,
    TorrentGalaxyIndexer? torrentGalaxyIndexer,
    LimeTorrentsIndexer? limeTorrentsIndexer,
  })  : _settings = settings ?? const IndexerSettings(),
        _leetIndexer = leetIndexer,
        _pirateBayIndexer = pirateBayIndexer,
        _solidtorrentsIndexer = solidtorrentsIndexer,
        _bitsearchIndexer = bitsearchIndexer,
        _btdigIndexer = btdigIndexer,
        _nyaaIndexer = nyaaIndexer,
        _torrentGalaxyIndexer = torrentGalaxyIndexer,
        _limeTorrentsIndexer = limeTorrentsIndexer;

  final IndexerSettings _settings;
  final LeetIndexer? _leetIndexer;
  final PirateBayIndexer? _pirateBayIndexer;
  final SolidtorrentsIndexer? _solidtorrentsIndexer;
  final BitsearchIndexer? _bitsearchIndexer;
  final BtdigIndexer? _btdigIndexer;
  final NyaaIndexer? _nyaaIndexer;
  final TorrentGalaxyIndexer? _torrentGalaxyIndexer;
  final LimeTorrentsIndexer? _limeTorrentsIndexer;

  /// Per-indexer search timeout.
  static const _indexerTimeout = Duration(seconds: 15);

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

    if (_settings.solidtorrentsEnabled) {
      final indexer = _solidtorrentsIndexer ?? SolidtorrentsIndexer();
      futures.add(
        _safeSearch(
          indexer.search(query),
          SolidtorrentsIndexer.sourceName,
        ),
      );
    }

    if (_settings.bitsearchEnabled) {
      final indexer = _bitsearchIndexer ?? BitsearchIndexer();
      futures.add(
        _safeSearch(indexer.search(query), BitsearchIndexer.sourceName),
      );
    }

    if (_settings.btdigEnabled) {
      final indexer = _btdigIndexer ?? BtdigIndexer();
      futures.add(_safeSearch(indexer.search(query), BtdigIndexer.sourceName));
    }

    if (_settings.nyaaEnabled) {
      final indexer = _nyaaIndexer ?? NyaaIndexer();
      futures.add(_safeSearch(indexer.search(query), NyaaIndexer.sourceName));
    }

    if (_settings.torrentGalaxyEnabled) {
      final indexer = _torrentGalaxyIndexer ?? TorrentGalaxyIndexer();
      futures.add(
        _safeSearch(indexer.search(query), TorrentGalaxyIndexer.sourceName),
      );
    }

    if (_settings.limeTorrentsEnabled) {
      final indexer = _limeTorrentsIndexer ?? LimeTorrentsIndexer();
      futures.add(
        _safeSearch(indexer.search(query), LimeTorrentsIndexer.sourceName),
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

  /// Wraps an indexer search so a single failure or timeout doesn't kill
  /// all results. Each indexer is bounded to [_indexerTimeout].
  Future<List<SearchResult>> _safeSearch(
    Future<List<SearchResult>> search,
    String sourceName,
  ) async {
    try {
      return await search.timeout(_indexerTimeout);
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

  /// Deduplicates results, preferring the entry with more seeds.
  ///
  /// Primary key: info_hash extracted from the magnet URI (when present).
  /// Fallback key: normalized title similarity.
  static List<SearchResult> _deduplicate(List<SearchResult> results) {
    final seen = <String, SearchResult>{};
    for (final result in results) {
      final key = _deduplicationKey(result);
      final existing = seen[key];
      if (existing == null || result.seeds > existing.seeds) {
        seen[key] = result;
      }
    }
    return seen.values.toList();
  }

  /// Returns the deduplication key for [result].
  ///
  /// Uses the lowercase info_hash from the magnet URI when available so that
  /// the same torrent reported by multiple indexers is correctly collapsed.
  /// Falls back to a normalized title key for indexers that don't embed a hash.
  static String _deduplicationKey(SearchResult result) {
    final hash = _extractInfoHash(result.magnetUri);
    if (hash != null) return 'hash:$hash';
    return 'title:${_normalizeTitle(result.title)}';
  }

  /// Extracts the lowercase info_hash from a magnet URI, or `null` if absent.
  static String? _extractInfoHash(String magnetUri) {
    final match = RegExp(
      r'btih:([a-fA-F0-9]{40})',
      caseSensitive: false,
    ).firstMatch(magnetUri);
    return match?.group(1)?.toLowerCase();
  }

  /// Normalizes a title for deduplication comparison.
  static String _normalizeTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }
}
