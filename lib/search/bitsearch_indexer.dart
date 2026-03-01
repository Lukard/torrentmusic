import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'leet_indexer.dart';
import 'search_result.dart';

/// Scrapes Bitsearch for audio torrents (category 6).
class BitsearchIndexer {
  /// Creates a [BitsearchIndexer].
  ///
  /// An optional [client] and [baseUrl] can be injected for testing.
  BitsearchIndexer({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://bitsearch.to';

  final http.Client _client;
  final String _baseUrl;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'Bitsearch';

  /// Timeout applied to HTTP requests.
  static const _requestTimeout = Duration(seconds: 10);

  static const _userAgent = 'Mozilla/5.0 (compatible; TorrentMusic/1.0)';

  /// Search Bitsearch for audio torrents matching [query].
  Future<List<SearchResult>> search(String query) async {
    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {'q': query, 'category': '6'},
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

  /// Parses Bitsearch HTML into [SearchResult]s.
  ///
  /// Public so unit tests can exercise it directly.
  static List<SearchResult> parseSearchPage(String html) {
    final document = html_parser.parse(html);
    final cards = document.querySelectorAll('li.search-result');

    final results = <SearchResult>[];
    for (final card in cards) {
      final titleAnchor = card.querySelector('.title a');
      if (titleAnchor == null) continue;

      final title = titleAnchor.text.trim();
      if (title.isEmpty) continue;

      // Magnet link is embedded directly in the result card.
      String? magnet;
      for (final anchor in card.querySelectorAll('a')) {
        final href = anchor.attributes['href'];
        if (href != null && href.startsWith('magnet:')) {
          magnet = href;
          break;
        }
      }
      if (magnet == null) continue;

      final seeds =
          int.tryParse(card.querySelector('.seed')?.text.trim() ?? '') ?? 0;
      final leeches =
          int.tryParse(card.querySelector('.leech')?.text.trim() ?? '') ?? 0;

      // The size span sits alongside the seed/leech badges inside .stats.
      // It is the first <span> that does NOT carry the .seed or .leech class.
      var sizeText = '';
      for (final span in card.querySelectorAll('.stats span')) {
        final cls = span.attributes['class'] ?? '';
        if (!cls.contains('seed') && !cls.contains('leech')) {
          sizeText = span.text.trim();
          break;
        }
      }

      results.add(
        SearchResult(
          title: title,
          magnetUri: magnet,
          seeds: seeds,
          leeches: leeches,
          sizeBytes: LeetIndexer.parseSize(sizeText),
          source: sourceName,
          category: 'Music',
        ),
      );
    }

    return results;
  }
}
