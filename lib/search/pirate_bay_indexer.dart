import 'dart:convert';

import 'package:http/http.dart' as http;

import 'search_result.dart';

/// Searches The Pirate Bay via the apibay.org proxy API.
class PirateBayIndexer {
  /// Creates a [PirateBayIndexer].
  ///
  /// An optional [client] and [baseUrl] can be injected for testing.
  PirateBayIndexer({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://apibay.org';

  final http.Client _client;
  final String _baseUrl;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'PirateBay';

  /// Timeout applied to API requests.
  static const _requestTimeout = Duration(seconds: 15);

  /// Standard BitTorrent trackers appended to magnet URIs.
  static const _trackers = [
    'udp://tracker.coppersurfer.tk:6969/announce',
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://tracker.leechers-paradise.org:6969/announce',
    'udp://p4p.arenabg.com:1337/announce',
  ];

  /// Search The Pirate Bay for music torrents matching [query].
  ///
  /// Uses category 101 (Music) via the apibay.org API.
  Future<List<SearchResult>> search(String query) async {
    final uri = Uri.parse('$_baseUrl/q.php').replace(
      queryParameters: {
        'q': query,
        'cat': '101',
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_requestTimeout);
    } on Exception {
      return [];
    }

    if (response.statusCode != 200) return [];

    return parseResponse(response.body);
  }

  /// Parses the JSON response from apibay.org into [SearchResult]s.
  ///
  /// Public so unit tests can exercise it directly.
  static List<SearchResult> parseResponse(String body) {
    final List<dynamic> items;
    try {
      items = jsonDecode(body) as List<dynamic>;
    } on FormatException {
      return [];
    }

    final results = <SearchResult>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      final name = item['name'] as String? ?? '';
      final infoHash = item['info_hash'] as String? ?? '';

      // apibay returns a single entry with id "0" when there are no results.
      if (infoHash.isEmpty || infoHash == '0' || name.isEmpty) continue;

      final seeds = _parseInt(item['seeders']);
      final leeches = _parseInt(item['leechers']);
      final sizeBytes = _parseLong(item['size']);

      final magnetUri = _buildMagnetUri(infoHash, name);

      results.add(
        SearchResult(
          title: name,
          magnetUri: magnetUri,
          seeds: seeds,
          leeches: leeches,
          sizeBytes: sizeBytes,
          source: sourceName,
          category: 'Music',
        ),
      );
    }

    return results;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int _parseLong(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _buildMagnetUri(String infoHash, String name) {
    final encodedName = Uri.encodeComponent(name);
    final trackerParams =
        _trackers.map((t) => '&tr=${Uri.encodeComponent(t)}').join();
    return 'magnet:?xt=urn:btih:$infoHash&dn=$encodedName$trackerParams';
  }
}
