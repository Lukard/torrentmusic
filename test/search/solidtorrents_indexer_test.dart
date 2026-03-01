import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/solidtorrents_indexer.dart';

void main() {
  group('SolidtorrentsIndexer.parseResponse', () {
    test('parses valid JSON response', () {
      final results = SolidtorrentsIndexer.parseResponse(_validJson);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(results[0].magnetUri, startsWith('magnet:?xt=urn:btih:AABBCC'));
      expect(results[0].seeds, 120);
      expect(results[0].leeches, 8);
      expect(results[0].sizeBytes, 734003200);
      expect(results[0].source, 'Solidtorrents');
      expect(results[0].category, 'Music');

      expect(results[1].title, 'Radiohead - OK Computer [MP3 320]');
      expect(results[1].seeds, 45);
      expect(results[1].leeches, 3);
    });

    test('returns empty list for missing results key', () {
      expect(
        SolidtorrentsIndexer.parseResponse('{"total":0}'),
        isEmpty,
      );
    });

    test('returns empty list for invalid JSON', () {
      expect(SolidtorrentsIndexer.parseResponse('not json'), isEmpty);
    });

    test('returns empty list for empty results array', () {
      expect(
        SolidtorrentsIndexer.parseResponse('{"results":[]}'),
        isEmpty,
      );
    });

    test('skips entries with empty magnet', () {
      final json = jsonEncode({
        'results': [
          {
            'title': 'Some Album',
            'magnet': '',
            'swarm': {'seeders': 5, 'leechers': 1},
            'size': 1024,
          },
        ],
      });
      expect(SolidtorrentsIndexer.parseResponse(json), isEmpty);
    });

    test('skips entries with non-magnet URI', () {
      final json = jsonEncode({
        'results': [
          {
            'title': 'Some Album',
            'magnet': 'http://example.com/torrent.torrent',
            'swarm': {'seeders': 5, 'leechers': 1},
            'size': 1024,
          },
        ],
      });
      expect(SolidtorrentsIndexer.parseResponse(json), isEmpty);
    });

    test('skips entries with empty title', () {
      final json = jsonEncode({
        'results': [
          {
            'title': '',
            'magnet': 'magnet:?xt=urn:btih:AABBCC',
            'swarm': {'seeders': 5, 'leechers': 1},
            'size': 1024,
          },
        ],
      });
      expect(SolidtorrentsIndexer.parseResponse(json), isEmpty);
    });

    test('handles missing swarm object gracefully', () {
      final json = jsonEncode({
        'results': [
          {
            'title': 'Album',
            'magnet': 'magnet:?xt=urn:btih:CCDDEE',
            'size': 2048,
          },
        ],
      });
      final results = SolidtorrentsIndexer.parseResponse(json);
      expect(results, hasLength(1));
      expect(results[0].seeds, 0);
      expect(results[0].leeches, 0);
    });

    test('handles string numeric fields in swarm', () {
      final json = jsonEncode({
        'results': [
          {
            'title': 'Album',
            'magnet': 'magnet:?xt=urn:btih:DDEEFF',
            'swarm': {'seeders': '77', 'leechers': '12'},
            'size': '1048576',
          },
        ],
      });
      final results = SolidtorrentsIndexer.parseResponse(json);
      expect(results[0].seeds, 77);
      expect(results[0].leeches, 12);
      expect(results[0].sizeBytes, 1048576);
    });
  });

  group('SolidtorrentsIndexer.search (integration)', () {
    test('makes correct request and returns results from mock HTTP', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], 'pink floyd');
        expect(request.url.queryParameters['category'], 'Audio');
        expect(request.headers['User-Agent'], isNotEmpty);
        return http.Response(_validJson, 200);
      });

      final indexer = SolidtorrentsIndexer(
        client: client,
        baseUrl: 'https://solidtorrents.to',
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(results[0].source, 'Solidtorrents');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient((_) async => http.Response('error', 503));

      final indexer =
          SolidtorrentsIndexer(client: client, baseUrl: 'https://example.com');
      expect(await indexer.search('test'), isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer =
          SolidtorrentsIndexer(client: client, baseUrl: 'https://example.com');
      expect(await indexer.search('test'), isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// JSON fixture
// ---------------------------------------------------------------------------

final _validJson = jsonEncode({
  'total': 2,
  'results': [
    {
      'title': 'Pink Floyd - The Wall [FLAC]',
      'magnet': 'magnet:?xt=urn:btih:AABBCCDDEEFF00112233445566778899AABBCCDD'
          '&dn=Pink+Floyd+-+The+Wall+FLAC',
      'swarm': {'seeders': 120, 'leechers': 8},
      'size': 734003200,
    },
    {
      'title': 'Radiohead - OK Computer [MP3 320]',
      'magnet': 'magnet:?xt=urn:btih:DDEEFF001122334455667788990011AABBCCDDEE'
          '&dn=Radiohead+-+OK+Computer+MP3+320',
      'swarm': {'seeders': 45, 'leechers': 3},
      'size': 104857600,
    },
  ],
});
