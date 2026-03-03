import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/torrent_galaxy_indexer.dart';

void main() {
  group('TorrentGalaxyIndexer.parseSize', () {
    test('parses MB', () {
      expect(
        TorrentGalaxyIndexer.parseSize('700 MB'),
        700 * 1024 * 1024,
      );
    });

    test('parses GB', () {
      expect(
        TorrentGalaxyIndexer.parseSize('1.5 GB'),
        (1.5 * 1024 * 1024 * 1024).round(),
      );
    });

    test('is case-insensitive', () {
      expect(
        TorrentGalaxyIndexer.parseSize('200 mb'),
        200 * 1024 * 1024,
      );
    });

    test('returns 0 for empty string', () {
      expect(TorrentGalaxyIndexer.parseSize(''), 0);
    });

    test('returns 0 for unrecognised format', () {
      expect(TorrentGalaxyIndexer.parseSize('unknown'), 0);
    });
  });

  group('TorrentGalaxyIndexer.parseSearchPage', () {
    test('extracts results from typical search HTML', () {
      final results = TorrentGalaxyIndexer.parseSearchPage(_searchPageHtml);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(
        results[0].magnetUri,
        startsWith('magnet:?xt=urn:btih:ABCDEF1234567890'),
      );
      expect(results[0].seeds, 150);
      expect(results[0].leeches, 20);
      expect(results[0].sizeBytes, 700 * 1024 * 1024);
      expect(results[0].source, 'TorrentGalaxy');
      expect(results[0].category, 'Music');

      expect(results[1].title, 'Pink Floyd - DSOTM [MP3 320kbps]');
      expect(results[1].seeds, 75);
      expect(results[1].leeches, 10);
    });

    test('returns empty list for HTML without result rows', () {
      expect(
        TorrentGalaxyIndexer.parseSearchPage('<html><body></body></html>'),
        isEmpty,
      );
    });

    test('skips rows without a /torrent/ link', () {
      const html = '''
<div class="tgxtablerow txlight">
  <div class="tgxtablecell">no torrent link here</div>
  <div class="tgxtablecell" id="seedsn">10</div>
  <div class="tgxtablecell" id="leechsn">2</div>
  <div class="tgxtablecell">
    <a href="magnet:?xt=urn:btih:AAAA1111AAAA1111AAAA1111AAAA1111AAAA1111">mag</a>
  </div>
</div>
''';
      expect(TorrentGalaxyIndexer.parseSearchPage(html), isEmpty);
    });

    test('skips rows without a magnet link', () {
      const html = '''
<div class="tgxtablerow txlight">
  <div class="tgxtablecell">
    <a href="/torrent/1/Name"><b>Name</b></a>
  </div>
  <div class="tgxtablecell" id="seedsn">10</div>
  <div class="tgxtablecell" id="leechsn">2</div>
</div>
''';
      expect(TorrentGalaxyIndexer.parseSearchPage(html), isEmpty);
    });

    test('defaults seeds and leeches to 0 when cells are absent', () {
      const html = '''
<div class="tgxtablerow txlight">
  <div class="tgxtablecell">
    <a href="/torrent/1/Name"><b>Test Album</b></a>
  </div>
  <div class="tgxtablecell">100 MB</div>
  <div class="tgxtablecell">
    <a href="magnet:?xt=urn:btih:BBBB2222BBBB2222BBBB2222BBBB2222BBBB2222">mag</a>
  </div>
</div>
''';
      final results = TorrentGalaxyIndexer.parseSearchPage(html);
      expect(results, hasLength(1));
      expect(results[0].seeds, 0);
      expect(results[0].leeches, 0);
    });
  });

  group('TorrentGalaxyIndexer.search (integration)', () {
    test('returns parsed SearchResults from mock HTTP', () async {
      final client = MockClient(
        (_) async => http.Response(_searchPageHtml, 200),
      );

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: ['https://torrentgalaxy.to'],
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(results[0].source, 'TorrentGalaxy');
      expect(results[0].category, 'Music');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient(
        (_) async => http.Response('Server Error', 500),
      );

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: ['https://torrentgalaxy.to'],
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: ['https://torrentgalaxy.to'],
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('sends User-Agent header', () async {
      String? userAgent;
      final client = MockClient((request) async {
        userAgent = request.headers['User-Agent'];
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: ['https://torrentgalaxy.to'],
      );
      await indexer.search('test');

      expect(userAgent, isNotNull);
      expect(userAgent, isNotEmpty);
    });

    test('encodes query and sets music category in URL', () async {
      Uri? requestUri;
      final client = MockClient((request) async {
        requestUri = request.url;
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: ['https://torrentgalaxy.to'],
      );
      await indexer.search('pink floyd');

      expect(requestUri?.queryParameters['search'], 'pink floyd');
      expect(requestUri?.queryParameters['c41'], '1');
    });
  });

  group('TorrentGalaxyIndexer mirror fallback', () {
    test('falls back to second mirror when first returns non-200', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (request.url.host == 'mirror1.example.com') {
          return http.Response('Blocked', 403);
        }
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: [
          'https://mirror1.example.com',
          'https://mirror2.example.com',
        ],
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(requestCount, 2);
    });

    test('falls back on network exception', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) throw Exception('timeout');
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: [
          'https://mirror1.example.com',
          'https://mirror2.example.com',
        ],
      );
      final results = await indexer.search('test');

      expect(results, hasLength(2));
    });

    test('returns empty when all mirrors fail', () async {
      final client = MockClient(
        (_) async => http.Response('Blocked', 403),
      );

      final indexer = TorrentGalaxyIndexer(
        client: client,
        mirrors: [
          'https://mirror1.example.com',
          'https://mirror2.example.com',
        ],
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// HTML fixtures
// ---------------------------------------------------------------------------

const _searchPageHtml = '''
<html>
<body>
<div class="tgxtable">
  <div class="tgxtablerow txlight">
    <div class="tgxtablecell collapsehide txlight">
      <a href="/?c=41"><img src="/img/music.png" alt="Music"></a>
    </div>
    <div class="tgxtablecell">
      <a href="/torrent/654321/Pink-Floyd-The-Wall-FLAC"><b>Pink Floyd - The Wall [FLAC]</b></a>
    </div>
    <div class="tgxtablecell collapsehide txlight">musicfan</div>
    <div class="tgxtablecell txlight">700 MB</div>
    <div class="tgxtablecell collapsehide txlight">2024-01-05</div>
    <div class="tgxtablecell" id="seedsn">150</div>
    <div class="tgxtablecell" id="leechsn">20</div>
    <div class="tgxtablecell">
      <a href="magnet:?xt=urn:btih:ABCDEF1234567890ABCDEF1234567890ABCDEF12&amp;dn=Pink+Floyd"><i class="fas fa-magnet"></i></a>
      <a href="https://torrentgalaxy.to/get/654321.torrent"><i class="fas fa-download"></i></a>
    </div>
  </div>
  <div class="tgxtablerow txlight">
    <div class="tgxtablecell collapsehide txlight">
      <a href="/?c=41"><img src="/img/music.png" alt="Music"></a>
    </div>
    <div class="tgxtablecell">
      <a href="/torrent/123456/Pink-Floyd-DSOTM-MP3-320kbps"><b>Pink Floyd - DSOTM [MP3 320kbps]</b></a>
    </div>
    <div class="tgxtablecell collapsehide txlight">audiophile</div>
    <div class="tgxtablecell txlight">120 MB</div>
    <div class="tgxtablecell collapsehide txlight">2024-01-12</div>
    <div class="tgxtablecell" id="seedsn">75</div>
    <div class="tgxtablecell" id="leechsn">10</div>
    <div class="tgxtablecell">
      <a href="magnet:?xt=urn:btih:FEDCBA0987654321FEDCBA0987654321FEDCBA09&amp;dn=Pink+Floyd+-+DSOTM"><i class="fas fa-magnet"></i></a>
      <a href="https://torrentgalaxy.to/get/123456.torrent"><i class="fas fa-download"></i></a>
    </div>
  </div>
</div>
</body>
</html>
''';
