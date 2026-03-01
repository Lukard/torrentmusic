import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'leet_indexer.dart';
import 'search_result.dart';

/// Standard BitTorrent trackers appended to magnet URIs built from
/// BTDig info hashes.
const _kTrackers = [
  'udp://tracker.coppersurfer.tk:6969/announce',
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://tracker.leechers-paradise.org:6969/announce',
];

/// Scrapes BTDig and constructs magnet URIs from the embedded info hashes.
///
/// BTDig does not expose seed counts, so [SearchResult.seeds] is always 0.
class BtdigIndexer {
  /// Creates a [BtdigIndexer].
  ///
  /// An optional [client] and [baseUrl] can be injected for testing.
  BtdigIndexer({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://btdig.com';

  final http.Client _client;
  final String _baseUrl;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'BTDig';

  /// Timeout applied to HTTP requests.
  static const _requestTimeout = Duration(seconds: 10);

  static const _userAgent = 'Mozilla/5.0 (compatible; TorrentMusic/1.0)';

  /// Regex that matches a 40-character hex info hash anywhere in a string.
  static final _infoHashRe = RegExp(r'[0-9a-fA-F]{40}');

  /// Search BTDig for torrents matching [query].
  Future<List<SearchResult>> search(String query) async {
    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {'q': query},
    );

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent},
      ).timeout(_requestTimeout);
    } on Exception {
      return [];
    }

    if (response.statusCode != 200) return [];

    return parseSearchPage(response.body);
  }

  /// Parses BTDig HTML into [SearchResult]s.
  ///
  /// Public so unit tests can exercise it directly.
  static List<SearchResult> parseSearchPage(String html) {
    final document = html_parser.parse(html);
    final items = document.querySelectorAll('.result');

    final results = <SearchResult>[];
    for (final item in items) {
      final nameAnchor = item.querySelector('.torrent_name a');
      if (nameAnchor == null) continue;

      final title = nameAnchor.text.trim();
      if (title.isEmpty) continue;

      // The info hash is embedded in the href, e.g. /abc123.../0.
      final href = nameAnchor.attributes['href'] ?? '';
      final hashMatch = _infoHashRe.firstMatch(href);
      if (hashMatch == null) continue;

      final infoHash = hashMatch.group(0)!;
      final sizeText = item.querySelector('.torrent_size')?.text.trim() ?? '';

      results.add(
        SearchResult(
          title: title,
          magnetUri: _buildMagnetUri(infoHash, title),
          seeds: 0, // BTDig does not publish seed counts.
          leeches: 0,
          sizeBytes: LeetIndexer.parseSize(sizeText),
          source: sourceName,
          category: 'Music',
        ),
      );
    }

    return results;
  }

  static String _buildMagnetUri(String infoHash, String name) {
    final encodedName = Uri.encodeComponent(name);
    final trackerParams =
        _kTrackers.map((t) => '&tr=${Uri.encodeComponent(t)}').join();
    return 'magnet:?xt=urn:btih:$infoHash&dn=$encodedName$trackerParams';
  }
}
