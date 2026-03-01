import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/bitsearch_indexer.dart';

void main() {
  group('BitsearchIndexer.parseSearchPage', () {
    test('parses typical search result HTML', () {
      final results = BitsearchIndexer.parseSearchPage(_searchHtml);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(
        results[0].magnetUri,
        startsWith('magnet:?xt=urn:btih:AABB'),
      );
      expect(results[0].seeds, 95);
      expect(results[0].leeches, 11);
      expect(results[0].sizeBytes, greaterThan(0)); // 700 MB
      expect(results[0].source, 'Bitsearch');
      expect(results[0].category, 'Music');

      expect(results[1].title, 'Radiohead - OK Computer [MP3 320]');
      expect(results[1].seeds, 40);
      expect(results[1].leeches, 5);
    });

    test('returns empty list for HTML without result cards', () {
      expect(
        BitsearchIndexer.parseSearchPage('<html><body></body></html>'),
        isEmpty,
      );
    });

    test('skips cards without a title link', () {
      const html = '''
<ul>
  <li class="search-result">
    <div class="details">
      <p class="stats">
        <span class="seed">5</span>
        <span class="leech">1</span>
        <span>100 MB</span>
      </p>
    </div>
  </li>
</ul>
''';
      expect(BitsearchIndexer.parseSearchPage(html), isEmpty);
    });

    test('skips cards without a magnet link', () {
      const html = '''
<ul>
  <li class="search-result">
    <div class="details">
      <h5 class="title"><a href="/torrent/abc/title">Title</a></h5>
      <p class="stats">
        <span class="seed">5</span>
        <span class="leech">1</span>
        <span>100 MB</span>
      </p>
      <a href="/download/abc">Download</a>
    </div>
  </li>
</ul>
''';
      expect(BitsearchIndexer.parseSearchPage(html), isEmpty);
    });

    test('defaults seeds/leeches to 0 on missing elements', () {
      const html = '''
<ul>
  <li class="search-result">
    <div class="details">
      <h5 class="title"><a href="/torrent/abc/title">No Stats Album</a></h5>
      <p class="stats"></p>
      <a href="magnet:?xt=urn:btih:CCDDEE112233">Magnet</a>
    </div>
  </li>
</ul>
''';
      final results = BitsearchIndexer.parseSearchPage(html);
      expect(results, hasLength(1));
      expect(results[0].seeds, 0);
      expect(results[0].leeches, 0);
      expect(results[0].sizeBytes, 0);
    });
  });

  group('BitsearchIndexer.search (integration)', () {
    test('makes correct request and returns results', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], 'pink floyd');
        expect(request.url.queryParameters['category'], '6');
        expect(request.headers['User-Agent'], isNotEmpty);
        return http.Response(_searchHtml, 200);
      });

      final indexer =
          BitsearchIndexer(client: client, baseUrl: 'https://bitsearch.to');
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].source, 'Bitsearch');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient((_) async => http.Response('error', 503));

      final indexer =
          BitsearchIndexer(client: client, baseUrl: 'https://example.com');
      expect(await indexer.search('test'), isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer =
          BitsearchIndexer(client: client, baseUrl: 'https://example.com');
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
<ul class="search-results">
  <li class="card search-result my-2">
    <div class="d-flex">
      <div class="details flex-grow-1">
        <h5 class="title">
          <a href="/torrent/AABBCCDDEEFF00112233445566778899AABBCCDD/pink-floyd-the-wall-flac">
            Pink Floyd - The Wall [FLAC]
          </a>
        </h5>
        <p class="stats">
          <span class="seed">95</span>
          <span class="leech">11</span>
          <span>700 MB</span>
        </p>
        <a href="magnet:?xt=urn:btih:AABBCCDDEEFF00112233445566778899AABBCCDD&amp;dn=Pink+Floyd">
          Magnet
        </a>
      </div>
    </div>
  </li>
  <li class="card search-result my-2">
    <div class="d-flex">
      <div class="details flex-grow-1">
        <h5 class="title">
          <a href="/torrent/DDEEFF001122334455667788990011AABBCCDDEE/radiohead-ok-computer">
            Radiohead - OK Computer [MP3 320]
          </a>
        </h5>
        <p class="stats">
          <span class="seed">40</span>
          <span class="leech">5</span>
          <span>100 MB</span>
        </p>
        <a href="magnet:?xt=urn:btih:DDEEFF001122334455667788990011AABBCCDDEE&amp;dn=Radiohead">
          Magnet
        </a>
      </div>
    </div>
  </li>
</ul>
</body>
</html>
''';
