import 'dart:convert';

import 'package:http/http.dart' as http;

import 'search_result.dart';
import 'spotify_config.dart';

/// Fetches track metadata from the Spotify Web API and maps it to
/// [SearchResult] objects.
///
/// Uses the Client Credentials OAuth flow — no user login required.
/// The access token is cached until it expires.
class SpotifySource {
  /// Creates a [SpotifySource] with the given [config].
  ///
  /// An optional [client] can be injected for testing.
  SpotifySource({
    required SpotifyConfig config,
    http.Client? client,
  })  : _config = config,
        _client = client ?? http.Client();

  final SpotifyConfig _config;
  final http.Client _client;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'Spotify';

  static const _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const _searchUrl = 'https://api.spotify.com/v1/search';

  /// Timeout applied to individual HTTP requests.
  static const _requestTimeout = Duration(seconds: 10);

  String? _cachedToken;
  DateTime? _tokenExpiry;

  /// Searches Spotify for tracks matching [query].
  ///
  /// Returns an empty list when credentials are not configured, when the
  /// token cannot be obtained, or when a network / API error occurs.
  Future<List<SearchResult>> search(String query) async {
    if (!_config.isConfigured) return [];

    final token = await _getToken();
    if (token == null) return [];

    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'q': query,
      'type': 'track',
      'limit': '20',
    });

    final http.Response response;
    try {
      response = await _client.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(_requestTimeout);
    } on Exception {
      return [];
    }

    if (response.statusCode == 429) {
      // Rate-limited — return empty rather than throw.
      return [];
    }

    if (response.statusCode == 401) {
      // Token rejected — clear cache so next call re-authenticates.
      _cachedToken = null;
      _tokenExpiry = null;
      return [];
    }

    if (response.statusCode != 200) return [];

    return parseSearchResponse(response.body);
  }

  /// Obtains an access token via the Client Credentials flow, caching it
  /// until it expires (minus a 60-second safety buffer).
  Future<String?> _getToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    final credentials = base64Encode(
      utf8.encode('${_config.clientId}:${_config.clientSecret}'),
    );

    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      ).timeout(_requestTimeout);
    } on Exception {
      return null;
    }

    if (response.statusCode != 200) return null;

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return null;
    }

    if (decoded is! Map<String, dynamic>) return null;

    final token = decoded['access_token'] as String?;
    if (token == null || token.isEmpty) return null;

    final expiresIn = decoded['expires_in'];
    final seconds =
        expiresIn is int ? expiresIn : int.tryParse('$expiresIn') ?? 3600;

    _cachedToken = token;
    // Subtract 60 s buffer so we re-auth slightly before actual expiry.
    _tokenExpiry = DateTime.now().add(Duration(seconds: seconds - 60));

    return _cachedToken;
  }

  /// Parses the Spotify search API JSON response into [SearchResult]s.
  ///
  /// Public so unit tests can exercise it directly without HTTP mocking.
  static List<SearchResult> parseSearchResponse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return [];
    }

    if (decoded is! Map<String, dynamic>) return [];

    final tracks = decoded['tracks'];
    if (tracks is! Map<String, dynamic>) return [];

    final items = tracks['items'];
    if (items is! List<dynamic>) return [];

    final results = <SearchResult>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      final id = item['id'] as String?;
      final name = item['name'] as String?;
      if (id == null || id.isEmpty || name == null || name.isEmpty) continue;

      // Use the first artist name when available.
      String artistName = '';
      final artists = item['artists'];
      if (artists is List<dynamic> && artists.isNotEmpty) {
        final first = artists[0];
        if (first is Map<String, dynamic>) {
          artistName = first['name'] as String? ?? '';
        }
      }

      final title = artistName.isNotEmpty ? '$artistName - $name' : name;

      final popularity = item['popularity'];
      final seeds =
          popularity is int ? popularity : int.tryParse('$popularity') ?? 0;

      final durationMs = item['duration_ms'];
      final sizeBytes =
          durationMs is int ? durationMs : int.tryParse('$durationMs') ?? 0;

      results.add(SearchResult(
        title: title,
        magnetUri: 'spotify:track:$id',
        seeds: seeds,
        leeches: 0,
        sizeBytes: sizeBytes,
        source: sourceName,
        category: 'Music',
      ));
    }

    return results;
  }
}
