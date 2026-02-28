/// Enum for search query type hints.
enum SearchType { track, album, artist }

/// Model representing a single torrent search result.
class SearchResult {
  /// Creates a [SearchResult] with the given metadata.
  const SearchResult({
    required this.title,
    required this.magnetUri,
    required this.seeds,
    required this.leeches,
    required this.sizeBytes,
    required this.source,
    this.category,
  });

  /// Display title of the torrent.
  final String title;

  /// Magnet URI used to start the torrent download.
  final String magnetUri;

  /// Number of seeders.
  final int seeds;

  /// Number of leechers.
  final int leeches;

  /// Total content size in bytes.
  final int sizeBytes;

  /// Name of the indexer that produced this result.
  final String source;

  /// Optional category tag (e.g. "Music", "Lossless").
  final String? category;

  @override
  String toString() =>
      'SearchResult(title: $title, seeds: $seeds, leeches: $leeches)';
}
