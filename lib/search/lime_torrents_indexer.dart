import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'search_result.dart';

const _kUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

/// Default LimeTorrents mirror URLs, tried in order when the current one
/// fails.
const kLimeTorrentsMirrors = [
  'https://www.limetorrents.lol',
  'https://www.limetorrents.co',
];

/// Scrapes the LimeTorrents public torrent indexer for music torrents.
class LimeTorrentsIndexer {
  /// Creates a [LimeTorrentsIndexer].
  ///
  /// An optional [client] and [mirrors] list can be injected for testing.
  LimeTorrentsIndexer({http.Client? client, List<String>? mirrors})
      : _client = client ?? http.Client(),
        _mirrors = mirrors ?? kLimeTorrentsMirrors;

  final http.Client _client;
  final List<String> _mirrors;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'LimeTorrents';

  /// Timeout applied to each HTTP request.
  static const _requestTimeout = Duration(seconds: 10);

  /// Search LimeTorrents for music torrents matching [query].
  ///
  /// Tries each mirror in order until one succeeds. Returns empty list if all
  /// mirrors fail.
  Future<List<SearchResult>> search(String query) async {
    final encoded = Uri.encodeComponent(query);

    for (final mirror in _mirrors) {
      final url = '$mirror/search/music/$encoded/seeds/1/';

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

  /// Parses the LimeTorrents search results page HTML into [SearchResult]s.
  ///
  /// LimeTorrents embeds the 40-character info hash in each torrent's detail
  /// page URL (e.g. `/torrent-name-HASH.html`), so magnet URIs can be
  /// constructed without fetching additional pages.
  static List<SearchResult> parseSearchPage(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('table.table2 tbody tr');

    final results = <SearchResult>[];
    for (final row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.length < 5) continue;

      // Title and detail URL.
      final titleLink = tds[0].querySelector('a');
      if (titleLink == null) continue;
      final title = titleLink.text.trim();
      final href = titleLink.attributes['href'] ?? '';
      if (title.isEmpty || href.isEmpty) continue;

      // Build magnet URI from the 40-char hex info hash embedded in the URL.
      final magnetUri = _buildMagnetFromHref(href, title);
      if (magnetUri == null) continue;

      final sizeText = tds[1].text.trim();

      // Seeds and leeches are in dedicated classes in the 4th and 5th cells.
      final seedsText =
          row.querySelector('td.tdseed')?.text.trim() ?? tds[3].text.trim();
      final leechesText =
          row.querySelector('td.tdleech')?.text.trim() ?? tds[4].text.trim();

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

  /// Extracts the 40-character hex info hash from a LimeTorrents detail URL
  /// and builds a magnet URI.
  ///
  /// Returns `null` if no valid hash is found in [href].
  static String? buildMagnetFromHref(String href, String title) =>
      _buildMagnetFromHref(href, title);

  static String? _buildMagnetFromHref(String href, String title) {
    final match = RegExp(r'([a-fA-F0-9]{40})').firstMatch(href);
    if (match == null) return null;
    final hash = match.group(1)!;
    final encodedName = Uri.encodeComponent(title);
    return 'magnet:?xt=urn:btih:$hash&dn=$encodedName';
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
}
