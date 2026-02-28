import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'search_result.dart';

/// Intermediate result from parsing the 1337x search page.
///
/// Contains everything except the magnet URI, which requires a
/// separate request to the torrent detail page.
class PartialResult {
  /// Creates a [PartialResult].
  const PartialResult({
    required this.title,
    required this.detailPath,
    required this.seeds,
    required this.leeches,
    required this.sizeBytes,
  });

  /// Torrent title.
  final String title;

  /// Relative path to the detail page (e.g. `/torrent/12345/Name/`).
  final String detailPath;

  /// Number of seeders.
  final int seeds;

  /// Number of leechers.
  final int leeches;

  /// Total content size in bytes.
  final int sizeBytes;
}

/// Scrapes the 1337x public torrent indexer for music torrents.
class LeetIndexer {
  /// Creates a [LeetIndexer].
  ///
  /// An optional [client] and [baseUrl] can be injected for testing.
  LeetIndexer({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://1337x.to';

  final http.Client _client;
  final String _baseUrl;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = '1337x';

  /// Maximum number of detail pages fetched per search.
  static const int _maxDetailFetches = 20;

  /// Timeout applied to each HTTP request.
  static const _requestTimeout = Duration(seconds: 15);

  /// Search 1337x for music torrents matching [query].
  Future<List<SearchResult>> search(String query) async {
    final encoded = Uri.encodeComponent(query);
    final url = '$_baseUrl/category-search/$encoded/Music/1/';

    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
    } on Exception {
      return [];
    }

    if (response.statusCode != 200) {
      return [];
    }

    final partials =
        parseSearchPage(response.body).take(_maxDetailFetches).toList();

    final results = await Future.wait(
      partials.map(_resolvePartial),
    );

    return results.whereType<SearchResult>().toList();
  }

  Future<SearchResult?> _resolvePartial(PartialResult partial) async {
    final magnetUri = await _fetchMagnetLink(partial.detailPath);
    if (magnetUri == null) return null;

    return SearchResult(
      title: partial.title,
      magnetUri: magnetUri,
      seeds: partial.seeds,
      leeches: partial.leeches,
      sizeBytes: partial.sizeBytes,
      source: sourceName,
      category: 'Music',
    );
  }

  Future<String?> _fetchMagnetLink(String detailPath) async {
    final url = '$_baseUrl$detailPath';

    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url)).timeout(_requestTimeout);
    } on Exception {
      return null;
    }

    if (response.statusCode != 200) return null;
    return parseDetailPage(response.body);
  }

  // ---------------------------------------------------------------------------
  // Static parsing helpers — public so unit tests can exercise them directly.
  // ---------------------------------------------------------------------------

  /// Parses the 1337x search results page HTML into [PartialResult]s.
  static List<PartialResult> parseSearchPage(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('table.table-list tbody tr');

    final results = <PartialResult>[];
    for (final row in rows) {
      final nameCell = row.querySelector('td.coll-1');
      if (nameCell == null) continue;

      // The first <a> is a category icon; the second has the title & path.
      final links = nameCell.querySelectorAll('a');
      if (links.length < 2) continue;

      final titleLink = links[1];
      final title = titleLink.text.trim();
      final detailPath = titleLink.attributes['href'] ?? '';
      if (detailPath.isEmpty) continue;

      final seedsText = row.querySelector('td.coll-2')?.text.trim() ?? '0';
      final leechesText = row.querySelector('td.coll-3')?.text.trim() ?? '0';

      // The size cell contains e.g. "350.5 MB<span>350.5</span>".
      // Using the full text and a regex avoids fragile DOM traversal.
      final sizeText = row.querySelector('td.coll-4')?.text ?? '';

      results.add(
        PartialResult(
          title: title,
          detailPath: detailPath,
          seeds: int.tryParse(seedsText) ?? 0,
          leeches: int.tryParse(leechesText) ?? 0,
          sizeBytes: parseSize(sizeText),
        ),
      );
    }

    return results;
  }

  /// Extracts the first magnet URI from a 1337x torrent detail page.
  static String? parseDetailPage(String html) {
    final document = html_parser.parse(html);
    for (final anchor in document.querySelectorAll('a')) {
      final href = anchor.attributes['href'];
      if (href != null && href.startsWith('magnet:')) {
        return href;
      }
    }
    return null;
  }

  /// Converts a human-readable size string (e.g. "1.2 GB") to bytes.
  static int parseSize(String sizeStr) {
    final match = RegExp(r'([\d.]+)\s*(KB|MB|GB|TB)', caseSensitive: false)
        .firstMatch(sizeStr.trim());
    if (match == null) return 0;

    final value = double.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toUpperCase();

    return switch (unit) {
      'KB' => (value * 1024).round(),
      'MB' => (value * 1024 * 1024).round(),
      'GB' => (value * 1024 * 1024 * 1024).round(),
      'TB' => (value * 1024 * 1024 * 1024 * 1024).round(),
      _ => 0,
    };
  }
}
