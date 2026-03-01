import 'dart:convert';

import 'package:http/http.dart' as http;

import 'search_result.dart';

/// Searches Solidtorrents via the public JSON API.
class SolidtorrentsIndexer {
  /// Creates a [SolidtorrentsIndexer].
  ///
  /// An optional [client] and [baseUrl] can be injected for testing.
  SolidtorrentsIndexer({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://solidtorrents.to';

  final http.Client _client;
  final String _baseUrl;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'Solidtorrents';

  /// Timeout applied to API requests.
  static const _requestTimeout = Duration(seconds: 10);

  static const _userAgent = 'Mozilla/5.0 (compatible; TorrentMusic/1.0)';

  /// Search Solidtorrents for audio torrents matching [query].
  Future<List<SearchResult>> search(String query) async {
    final uri = Uri.parse('$_baseUrl/api/v1/search').replace(
      queryParameters: {'q': query, 'category': 'Audio'},
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

    return parseResponse(response.body);
  }

  /// Parses the JSON response from the Solidtorrents API into [SearchResult]s.
  ///
  /// Public so unit tests can exercise it directly.
  static List<SearchResult> parseResponse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return [];
    }

    if (decoded is! Map<String, dynamic>) return [];

    final hits = decoded['results'];
    if (hits is! List<dynamic>) return [];

    final results = <SearchResult>[];
    for (final item in hits) {
      if (item is! Map<String, dynamic>) continue;

      final title = item['title'] as String? ?? '';
      final magnet = item['magnet'] as String? ?? '';
      if (title.isEmpty || magnet.isEmpty || !magnet.startsWith('magnet:')) {
        continue;
      }

      // Seed/leech counts live under the "swarm" sub-object.
      var seeds = 0;
      var leeches = 0;
      final swarm = item['swarm'];
      if (swarm is Map<String, dynamic>) {
        seeds = _parseInt(swarm['seeders']);
        leeches = _parseInt(swarm['leechers']);
      }

      final sizeBytes = _parseInt(item['size']);

      results.add(
        SearchResult(
          title: title,
          magnetUri: magnet,
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
}
