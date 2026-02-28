import 'leet_indexer.dart';
import 'search_result.dart';

/// Interface for searching torrent indexers for music content.
abstract class SearchService {
  /// Search for music torrents matching [query].
  ///
  /// An optional [type] hint can be provided to narrow results.
  Future<List<SearchResult>> search(String query, {SearchType? type});
}

/// Concrete [SearchService] that aggregates results from torrent indexers
/// and filters for audio content.
class TorrentSearchService implements SearchService {
  /// Creates a [TorrentSearchService].
  ///
  /// An optional [indexer] can be injected for testing.
  TorrentSearchService({LeetIndexer? indexer})
      : _indexer = indexer ?? LeetIndexer();

  final LeetIndexer _indexer;

  @override
  Future<List<SearchResult>> search(String query, {SearchType? type}) async {
    final results = await _indexer.search(query);
    return results.where(isAudioContent).toList();
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
      '.mkv',
      '.avi',
      '.mp4',
      '.wmv',
    ];
    return !videoIndicators.any(lower.contains);
  }
}
