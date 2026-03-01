import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/btdig_indexer.dart';

void main() {
  group('BtdigIndexer.parseSearchPage', () {
    test('parses typical search result HTML', () {
      final results = BtdigIndexer.parseSearchPage(_searchHtml);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(
        results[0].magnetUri,
        contains('urn:btih:aabbccddeeff00112233445566778899aabbccdd'),
      );
      expect(results[0].seeds, 0); // BTDig has no seed counts.
      expect(results[0].leeches, 0);
      expect(results[0].sizeBytes, greaterThan(0)); // 700 MB
      expect(results[0].source, 'BTDig');
      expect(results[0].category, 'Music');

      expect(results[1].title, 'Radiohead - OK Computer [MP3 320]');
      expect(
        results[1].magnetUri,
        contains('urn:btih:ddeeff001122334455667788990011aabbccddee'),
      );
    });

    test('magnet URI includes tracker parameters', () {
      final results = BtdigIndexer.parseSearchPage(_searchHtml);
      expect(results[0].magnetUri, contains('&tr='));
    });

    test('returns empty list for HTML without result items', () {
      expect(
        BtdigIndexer.parseSearchPage('<html><body></body></html>'),
        isEmpty,
      );
    });

    test('skips items with no torrent name anchor', () {
      const html = '''
<div class="result">
  <div class="torrent_size">100 MB</div>
</div>
''';
      expect(BtdigIndexer.parseSearchPage(html), isEmpty);
    });

    test('skips items where href contains no valid info hash', () {
      const html = '''
<div class="result">
  <div class="torrent_name">
    <a href="/not-a-hash/">Album Title</a>
  </div>
  <div class="torrent_size">100 MB</div>
</div>
''';
      expect(BtdigIndexer.parseSearchPage(html), isEmpty);
    });

    test('defaults sizeBytes to 0 when size element is absent', () {
      const html = '''
<div class="result">
  <div class="torrent_name">
    <a href="/aabbccddeeff00112233445566778899aabbccdd/0">No Size Album</a>
  </div>
</div>
''';
      final results = BtdigIndexer.parseSearchPage(html);
      expect(results, hasLength(1));
      expect(results[0].sizeBytes, 0);
    });

    test('extracts info hash case-insensitively', () {
      const html = '''
<div class="result">
  <div class="torrent_name">
    <a href="/AABBCCDDEEFF00112233445566778899AABBCCDD/0">Upper Case Hash</a>
  </div>
  <div class="torrent_size">50 MB</div>
</div>
''';
      final results = BtdigIndexer.parseSearchPage(html);
      expect(results, hasLength(1));
      expect(
        results[0].magnetUri,
        contains('AABBCCDDEEFF00112233445566778899AABBCCDD'),
      );
    });
  });

  group('BtdigIndexer.search (integration)', () {
    test('makes correct request and returns results', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], 'pink floyd');
        expect(request.headers['User-Agent'], isNotEmpty);
        return http.Response(_searchHtml, 200);
      });

      final indexer =
          BtdigIndexer(client: client, baseUrl: 'https://btdig.com');
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].source, 'BTDig');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient((_) async => http.Response('error', 503));

      final indexer =
          BtdigIndexer(client: client, baseUrl: 'https://example.com');
      expect(await indexer.search('test'), isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer =
          BtdigIndexer(client: client, baseUrl: 'https://example.com');
      expect(await indexer.search('test'), isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// HTML fixture
// ---------------------------------------------------------------------------

const _searchHtml = '''
<html>
<body>
<div id="results">
  <div class="result">
    <div class="torrent_name">
      <a href="/aabbccddeeff00112233445566778899aabbccdd/0">
        Pink Floyd - The Wall [FLAC]
      </a>
    </div>
    <div class="torrent_size">700 MB</div>
  </div>
  <div class="result">
    <div class="torrent_name">
      <a href="/ddeeff001122334455667788990011aabbccddee/0">
        Radiohead - OK Computer [MP3 320]
      </a>
    </div>
    <div class="torrent_size">100 MB</div>
  </div>
</div>
</body>
</html>
''';
