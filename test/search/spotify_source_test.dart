import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/spotify_config.dart';
import 'package:torrentmusic/search/spotify_source.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SpotifySource.parseSearchResponse — static, no HTTP
  // ---------------------------------------------------------------------------
  group('SpotifySource.parseSearchResponse', () {
    test('parses valid response with artist and track name', () {
      final results = SpotifySource.parseSearchResponse(_validSearchBody);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - Comfortably Numb');
      expect(results[0].magnetUri, 'spotify:track:abc123');
      expect(results[0].seeds, 85);
      expect(results[0].leeches, 0);
      expect(results[0].sizeBytes, 382000);
      expect(results[0].source, 'Spotify');
      expect(results[0].category, 'Music');

      expect(results[1].title, 'Radiohead - Creep');
      expect(results[1].seeds, 92);
      expect(results[1].sizeBytes, 239000);
    });

    test('uses track name alone when artists list is empty', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'id': 'solo1',
              'name': 'Untitled',
              'artists': <dynamic>[],
              'popularity': 40,
              'duration_ms': 200000,
            },
          ],
        },
      });

      final results = SpotifySource.parseSearchResponse(body);
      expect(results, hasLength(1));
      expect(results[0].title, 'Untitled');
    });

    test('handles item with no artists key', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'id': 'noartist1',
              'name': 'Mysterious Track',
              'popularity': 30,
              'duration_ms': 150000,
            },
          ],
        },
      });

      final results = SpotifySource.parseSearchResponse(body);
      expect(results, hasLength(1));
      expect(results[0].title, 'Mysterious Track');
    });

    test('uses first artist when multiple are present', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'id': 'multi1',
              'name': 'Collab Song',
              'artists': [
                {'name': 'Artist A'},
                {'name': 'Artist B'},
              ],
              'popularity': 60,
              'duration_ms': 210000,
            },
          ],
        },
      });

      final results = SpotifySource.parseSearchResponse(body);
      expect(results, hasLength(1));
      expect(results[0].title, 'Artist A - Collab Song');
    });

    test('skips items with missing id', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'name': 'No ID Track',
              'artists': [
                {'name': 'Someone'},
              ],
              'popularity': 50,
              'duration_ms': 180000,
            },
          ],
        },
      });

      expect(SpotifySource.parseSearchResponse(body), isEmpty);
    });

    test('skips items with empty id', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'id': '',
              'name': 'Empty ID Track',
              'popularity': 50,
              'duration_ms': 180000,
            },
          ],
        },
      });

      expect(SpotifySource.parseSearchResponse(body), isEmpty);
    });

    test('skips items with empty name', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'id': 'validid',
              'name': '',
              'popularity': 50,
              'duration_ms': 180000,
            },
          ],
        },
      });

      expect(SpotifySource.parseSearchResponse(body), isEmpty);
    });

    test('returns empty list for invalid JSON', () {
      expect(SpotifySource.parseSearchResponse('not json at all'), isEmpty);
    });

    test('returns empty list when tracks key is missing', () {
      expect(
        SpotifySource.parseSearchResponse(jsonEncode({'other': 'data'})),
        isEmpty,
      );
    });

    test('returns empty list when items key is missing', () {
      expect(
        SpotifySource.parseSearchResponse(
          jsonEncode({'tracks': {'total': 0}}),
        ),
        isEmpty,
      );
    });

    test('returns empty list for empty items array', () {
      expect(
        SpotifySource.parseSearchResponse(
          jsonEncode({'tracks': {'items': <dynamic>[]}},
          ),
        ),
        isEmpty,
      );
    });

    test('sets seeds from popularity field', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'id': 'pop100',
              'name': 'Very Popular',
              'popularity': 100,
              'duration_ms': 300000,
            },
          ],
        },
      });

      final results = SpotifySource.parseSearchResponse(body);
      expect(results[0].seeds, 100);
    });

    test('sets sizeBytes from duration_ms field', () {
      final body = jsonEncode({
        'tracks': {
          'items': [
            {
              'id': 'dur1',
              'name': 'Long Track',
              'popularity': 50,
              'duration_ms': 600000,
            },
          ],
        },
      });

      final results = SpotifySource.parseSearchResponse(body);
      expect(results[0].sizeBytes, 600000);
    });
  });

  // ---------------------------------------------------------------------------
  // SpotifySource.search — requires HTTP mocking
  // ---------------------------------------------------------------------------
  group('SpotifySource.search', () {
    test('returns empty list when config has no clientId', () async {
      final source = SpotifySource(
        config: const SpotifyConfig(clientId: '', clientSecret: 'secret'),
      );
      expect(await source.search('pink floyd'), isEmpty);
    });

    test('returns empty list when config has no clientSecret', () async {
      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: ''),
      );
      expect(await source.search('pink floyd'), isEmpty);
    });

    test('fetches token then searches and returns mapped results', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          expect(request.method, 'POST');
          expect(request.body, contains('grant_type=client_credentials'));
          expect(request.headers['Content-Type'],
              contains('application/x-www-form-urlencoded'));
          return http.Response(_tokenBody, 200);
        }
        if (request.url.host == 'api.spotify.com') {
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer test_access_token');
          expect(request.url.queryParameters['q'], 'pink floyd');
          expect(request.url.queryParameters['type'], 'track');
          return http.Response(_validSearchBody, 200);
        }
        return http.Response('unexpected', 404);
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      final results = await source.search('pink floyd');
      expect(results, hasLength(2));
      expect(results[0].source, 'Spotify');
      expect(results[0].magnetUri, startsWith('spotify:track:'));
    });

    test('caches token — second search reuses token without re-fetching',
        () async {
      var tokenRequestCount = 0;

      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          tokenRequestCount++;
          return http.Response(_tokenBody, 200);
        }
        return http.Response(_validSearchBody, 200);
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      await source.search('query one');
      await source.search('query two');

      expect(tokenRequestCount, 1);
    });

    test('returns empty list on 429 rate-limit response', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          return http.Response(_tokenBody, 200);
        }
        return http.Response('rate limited', 429);
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      expect(await source.search('test'), isEmpty);
    });

    test('returns empty and clears cached token on 401 response', () async {
      var tokenRequestCount = 0;

      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          tokenRequestCount++;
          return http.Response(_tokenBody, 200);
        }
        // First search gets 401; second search should re-fetch token.
        return http.Response('unauthorized', 401);
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      // First search returns empty and clears token.
      final results = await source.search('test');
      expect(results, isEmpty);

      // Second search must re-fetch the token.
      await source.search('test again');
      expect(tokenRequestCount, 2);
    });

    test('returns empty list on non-200 token response', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          return http.Response('bad credentials', 401);
        }
        return http.Response(_validSearchBody, 200);
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'bad', clientSecret: 'creds'),
        client: client,
      );

      expect(await source.search('test'), isEmpty);
    });

    test('returns empty list on network exception during search', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          return http.Response(_tokenBody, 200);
        }
        throw Exception('network error');
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      expect(await source.search('test'), isEmpty);
    });

    test('returns empty list on network exception during token fetch', () async {
      final client = MockClient((request) async {
        throw Exception('no internet');
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      expect(await source.search('test'), isEmpty);
    });

    test('returns empty list on non-200 search response', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          return http.Response(_tokenBody, 200);
        }
        return http.Response('server error', 500);
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      expect(await source.search('test'), isEmpty);
    });

    test('passes query verbatim to Spotify search endpoint', () async {
      String? capturedQuery;

      final client = MockClient((request) async {
        if (request.url.host == 'accounts.spotify.com') {
          return http.Response(_tokenBody, 200);
        }
        capturedQuery = request.url.queryParameters['q'];
        return http.Response(
          jsonEncode({'tracks': {'items': <dynamic>[]}}),
          200,
        );
      });

      final source = SpotifySource(
        config: const SpotifyConfig(clientId: 'id', clientSecret: 'secret'),
        client: client,
      );

      await source.search('Taylor Swift folklore');
      expect(capturedQuery, 'Taylor Swift folklore');
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _tokenBody = jsonEncode({
  'access_token': 'test_access_token',
  'token_type': 'Bearer',
  'expires_in': 3600,
});

final _validSearchBody = jsonEncode({
  'tracks': {
    'total': 2,
    'items': [
      {
        'id': 'abc123',
        'name': 'Comfortably Numb',
        'artists': [
          {'name': 'Pink Floyd'},
        ],
        'popularity': 85,
        'duration_ms': 382000,
      },
      {
        'id': 'def456',
        'name': 'Creep',
        'artists': [
          {'name': 'Radiohead'},
        ],
        'popularity': 92,
        'duration_ms': 239000,
      },
    ],
  },
});
