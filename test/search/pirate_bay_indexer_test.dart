import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/pirate_bay_indexer.dart';

void main() {
  group('PirateBayIndexer.parseResponse', () {
    test('parses valid JSON response', () {
      final results = PirateBayIndexer.parseResponse(_validJson);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall FLAC');
      expect(results[0].magnetUri, startsWith('magnet:?xt=urn:btih:ABC123'));
      expect(results[0].seeds, 100);
      expect(results[0].leeches, 15);
      expect(results[0].sizeBytes, 524288000);
      expect(results[0].source, 'PirateBay');
      expect(results[0].category, 'Music');

      expect(results[1].title, 'Radiohead - OK Computer MP3');
      expect(results[1].seeds, 50);
    });

    test('returns empty list for no-results response', () {
      // apibay returns [{"id":"0","name":"No results",...}] when empty.
      const json = '[{"id":"0","name":"No results returned","info_hash":"0",'
          '"leechers":"0","seeders":"0","num_files":"0","size":"0",'
          '"username":"","added":"0","status":"member","category":"0",'
          '"imdb":""}]';
      final results = PirateBayIndexer.parseResponse(json);
      expect(results, isEmpty);
    });

    test('returns empty list for invalid JSON', () {
      expect(PirateBayIndexer.parseResponse('not json'), isEmpty);
    });

    test('returns empty list for empty array', () {
      expect(PirateBayIndexer.parseResponse('[]'), isEmpty);
    });

    test('skips entries with empty info_hash', () {
      const json = '[{"name":"test","info_hash":"","seeders":"5",'
          '"leechers":"1","size":"1024"}]';
      expect(PirateBayIndexer.parseResponse(json), isEmpty);
    });

    test('handles string numeric fields', () {
      const json = '[{"name":"Album","info_hash":"HASH1",'
          '"seeders":"42","leechers":"7","size":"1048576"}]';
      final results = PirateBayIndexer.parseResponse(json);

      expect(results, hasLength(1));
      expect(results[0].seeds, 42);
      expect(results[0].leeches, 7);
      expect(results[0].sizeBytes, 1048576);
    });

    test('magnet URI includes trackers', () {
      const json = '[{"name":"Test","info_hash":"TESTHASH",'
          '"seeders":"1","leechers":"0","size":"100"}]';
      final results = PirateBayIndexer.parseResponse(json);

      expect(results[0].magnetUri, contains('&tr='));
      expect(results[0].magnetUri, contains('urn:btih:TESTHASH'));
    });
  });

  group('PirateBayIndexer.search (integration)', () {
    test('returns results from mock HTTP', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], 'pink floyd');
        expect(request.url.queryParameters['cat'], '101');
        return http.Response(_validJson, 200);
      });

      final indexer = PirateBayIndexer(
        client: client,
        baseUrl: 'https://apibay.org',
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].title, 'Pink Floyd - The Wall FLAC');
      expect(results[0].source, 'PirateBay');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient(
        (_) async => http.Response('error', 500),
      );

      final indexer = PirateBayIndexer(
        client: client,
        baseUrl: 'https://apibay.org',
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer = PirateBayIndexer(
        client: client,
        baseUrl: 'https://apibay.org',
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });
  });
}

final _validJson = jsonEncode([
  {
    'id': '12345',
    'name': 'Pink Floyd - The Wall FLAC',
    'info_hash': 'ABC123DEF456789012345678901234567890ABCD',
    'leechers': '15',
    'seeders': '100',
    'num_files': '20',
    'size': '524288000',
    'username': 'musicfan',
    'added': '1700000000',
    'status': 'vip',
    'category': '101',
    'imdb': '',
  },
  {
    'id': '67890',
    'name': 'Radiohead - OK Computer MP3',
    'info_hash': 'DEF789ABC123456789012345678901234567890X',
    'leechers': '5',
    'seeders': '50',
    'num_files': '12',
    'size': '104857600',
    'username': 'audiophile',
    'added': '1700100000',
    'status': 'member',
    'category': '101',
    'imdb': '',
  },
]);
