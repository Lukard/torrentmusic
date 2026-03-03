import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'search_result.dart';

const _kUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

/// Default Nyaa mirror URLs, tried in order when the current one fails.
const kNyaaMirrors = [
  'https://nyaa.si',
  'https://nyaa.land',
];

/// Scrapes the Nyaa.si public torrent indexer for audio torrents.
class NyaaIndexer {
  /// Creates a [NyaaIndexer].
  ///
  /// An optional [client] and [mirrors] list can be injected for testing.
  NyaaIndexer({http.Client? client, List<String>? mirrors})
      : _client = client ?? http.Client(),
        _mirrors = mirrors ?? kNyaaMirrors;

  final http.Client _client;
  final List<String> _mirrors;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'Nyaa';

  /// Timeout applied to each HTTP request.
  static const _requestTimeout = Duration(seconds: 10);

  /// Search Nyaa for audio torrents matching [query].
  ///
  /// Uses category 2_0 (Audio). Tries each mirror in order until one
  /// succeeds. Returns empty list if all mirrors fail.
  Future<List<SearchResult>> search(String query) async {
    final encoded = Uri.encodeComponent(query);

    for (final mirror in _mirrors) {
      final url = '$mirror/?q=$encoded&c=2_0&f=0&s=seeders&o=desc';

      final http.Response response;
      try {
        response = await _client.get(
          Uri.parse(url),
          headers: {'User-Agent': _kUserAgent},
        ).timeout(_requestTimeout);
      } on Exception {
        continue;
      }

      if (response.statusCode != 200) continue;

      return parseSearchPage(response.body);
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // Static parsing helpers — public so unit tests can exercise them directly.
  // ---------------------------------------------------------------------------

  /// Parses the Nyaa search results page HTML into [SearchResult]s.
  ///
  /// Nyaa shows magnet links directly on the search page, so no detail-page
  /// requests are needed.
  static List<SearchResult> parseSearchPage(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('table.torrent-list tbody tr');

    final results = <SearchResult>[];
    for (final row in rows) {
      // Title: prefer the `title` attribute on the /view/ link, fall back to
      // its text content.
      final titleLink = row.querySelector('a[href^="/view/"]');
      if (titleLink == null) continue;
      final title = (titleLink.attributes['title'] ?? titleLink.text).trim();
      if (title.isEmpty) continue;

      // Magnet link is directly available on the search page.
      final magnetLink = row.querySelector('a[href^="magnet:"]');
      final magnetUri = magnetLink?.attributes['href'];
      if (magnetUri == null) continue;

      // Nyaa uses CSS classes to colour seeders (green) and leechers (red).
      final seedsText =
          row.querySelector('td.text-success')?.text.trim() ?? '0';
      final leechesText =
          row.querySelector('td.text-danger')?.text.trim() ?? '0';

      // Size: find the first td whose text matches a byte-count pattern.
      final sizeText = _findSizeText(row.querySelectorAll('td'));

      results.add(
        SearchResult(
          title: title,
          magnetUri: magnetUri,
          seeds: int.tryParse(seedsText) ?? 0,
          leeches: int.tryParse(leechesText) ?? 0,
          sizeBytes: parseSize(sizeText),
          source: sourceName,
          category: 'Audio',
        ),
      );
    }

    return results;
  }

  /// Converts a human-readable size string (e.g. "1.2 GiB", "350 MB") to
  /// bytes. Handles both SI (MB/GB) and binary (MiB/GiB) suffixes, treating
  /// both as powers of 1024 (the convention used by torrent sites).
  static int parseSize(String sizeStr) {
    final match = RegExp(r'([\d.]+)\s*([KMGT])i?B', caseSensitive: false)
        .firstMatch(sizeStr.trim());
    if (match == null) return 0;

    final value = double.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toUpperCase();

    const ki = 1024;
    return switch (unit) {
      'K' => (value * ki).round(),
      'M' => (value * ki * ki).round(),
      'G' => (value * ki * ki * ki).round(),
      'T' => (value * ki * ki * ki * ki).round(),
      _ => 0,
    };
  }

  static final _sizePattern =
      RegExp(r'[\d.]+\s*[KMGT]i?B', caseSensitive: false);

  static String _findSizeText(List<Element> tds) {
    for (final td in tds) {
      final text = td.text.trim();
      if (_sizePattern.hasMatch(text) && text.length < 20) return text;
    }
    return '';
  }
}
