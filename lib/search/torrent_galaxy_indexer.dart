import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'search_result.dart';

const _kUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

/// Default TorrentGalaxy mirror URLs, tried in order when the current one
/// fails.
const kTorrentGalaxyMirrors = [
  'https://torrentgalaxy.to',
  'https://tgx.rs',
];

/// Scrapes the TorrentGalaxy public torrent indexer for music torrents.
class TorrentGalaxyIndexer {
  /// Creates a [TorrentGalaxyIndexer].
  ///
  /// An optional [client] and [mirrors] list can be injected for testing.
  TorrentGalaxyIndexer({http.Client? client, List<String>? mirrors})
      : _client = client ?? http.Client(),
        _mirrors = mirrors ?? kTorrentGalaxyMirrors;

  final http.Client _client;
  final List<String> _mirrors;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'TorrentGalaxy';

  /// Timeout applied to each HTTP request.
  static const _requestTimeout = Duration(seconds: 10);

  /// Search TorrentGalaxy for music torrents matching [query].
  ///
  /// Uses category c41 (Music). Tries each mirror in order until one
  /// succeeds. Returns empty list if all mirrors fail.
  Future<List<SearchResult>> search(String query) async {
    final encoded = Uri.encodeComponent(query);

    for (final mirror in _mirrors) {
      final url =
          '$mirror/torrents.php?search=$encoded&sort=seeders&order=desc&c41=1';

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

  /// Parses the TorrentGalaxy search results page HTML into [SearchResult]s.
  ///
  /// TorrentGalaxy uses a div-based layout. Each result row is a
  /// `div.tgxtablerow`. Magnet links are present directly on the search page.
  static List<SearchResult> parseSearchPage(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('div.tgxtablerow');

    final results = <SearchResult>[];
    for (final row in rows) {
      // Title: first link pointing to a torrent detail page.
      final titleLink = row.querySelector('a[href*="/torrent/"]');
      if (titleLink == null) continue;
      // The visible text is often wrapped in a <b> tag; .text recurses into
      // children so this works regardless.
      final title = titleLink.text.trim();
      if (title.isEmpty) continue;

      // Magnet link is directly available on the search page.
      final magnetLink = row.querySelector('a[href^="magnet:"]');
      final magnetUri = magnetLink?.attributes['href'];
      if (magnetUri == null) continue;

      // TorrentGalaxy marks seeder/leecher cells with specific ids.
      // Using attribute-selector form avoids potential id-map short-circuits
      // when ids are duplicated across rows.
      final seedsText = row.querySelector('[id="seedsn"]')?.text.trim() ?? '0';
      final leechesText =
          row.querySelector('[id="leechsn"]')?.text.trim() ?? '0';

      // Size: scan `.tgxtablecell` divs for a cell whose text matches a
      // byte-count pattern (avoids fragile positional indexing).
      final sizeText = _extractSize(row);

      results.add(
        SearchResult(
          title: title,
          magnetUri: magnetUri,
          seeds: int.tryParse(seedsText) ?? 0,
          leeches: int.tryParse(leechesText) ?? 0,
          sizeBytes: parseSize(sizeText),
          source: sourceName,
          category: 'Music',
        ),
      );
    }

    return results;
  }

  /// Converts a human-readable size string (e.g. "1.2 GB", "350 MB") to
  /// bytes.
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

  static String _extractSize(Element row) {
    for (final cell in row.querySelectorAll('div.tgxtablecell')) {
      final text = cell.text.trim();
      if (_sizePattern.hasMatch(text) && text.length < 20) return text;
    }
    return '';
  }
}
