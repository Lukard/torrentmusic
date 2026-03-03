import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/lime_torrents_indexer.dart';

void main() {
  group('LimeTorrentsIndexer.parseSize', () {
    test('parses MB', () {
      expect(
        LimeTorrentsIndexer.parseSize('800.54 MB'),
        (800.54 * 1024 * 1024).round(),
      );
    });

    test('parses GB', () {
      expect(
        LimeTorrentsIndexer.parseSize('2.0 GB'),
        (2.0 * 1024 * 1024 * 1024).round(),
      );
    });

    test('parses KB', () {
      expect(LimeTorrentsIndexer.parseSize('512 KB'), 512 * 1024);
    });

    test('is case-insensitive', () {
      expect(LimeTorrentsIndexer.parseSize('100 mb'), 100 * 1024 * 1024);
    });

    test('returns 0 for empty string', () {
      expect(LimeTorrentsIndexer.parseSize(''), 0);
    });

    test('returns 0 for unrecognised format', () {
      expect(LimeTorrentsIndexer.parseSize('unknown'), 0);
    });
  });

  group('LimeTorrentsIndexer.buildMagnetFromHref', () {
    test('extracts 40-char hex hash and builds magnet URI', () {
      const href =
          '/Pink-Floyd-The-Wall-FLAC-torrent-ABCDEF1234567890ABCDEF1234567890ABCDEF12.html';
      final magnet = LimeTorrentsIndexer.buildMagnetFromHref(
        href,
        'Pink Floyd - The Wall [FLAC]',
      );

      expect(magnet, isNotNull);
      expect(magnet, startsWith('magnet:?xt=urn:btih:ABCDEF1234567890'));
      expect(magnet, contains('dn='));
    });

    test('returns null when no 40-char hex is found', () {
      expect(
        LimeTorrentsIndexer.buildMagnetFromHref('/no-hash-here.html', 'Title'),
        isNull,
      );
    });

    test('handles mixed-case hash', () {
      const href = '/torrent-abcdef1234567890ABCDEF1234567890abcdef12.html';
      final magnet =
          LimeTorrentsIndexer.buildMagnetFromHref(href, 'Test Album');
      expect(magnet, isNotNull);
      expect(magnet, contains('urn:btih:abcdef1234567890ABCDEF'));
    });
  });

  group('LimeTorrentsIndexer.parseSearchPage', () {
    test('extracts results from typical search HTML', () {
      final results = LimeTorrentsIndexer.parseSearchPage(_searchPageHtml);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(
        results[0].magnetUri,
        startsWith(
          'magnet:?xt=urn:btih:ABCDEF1234567890ABCDEF1234567890ABCDEF12',
        ),
      );
      expect(results[0].seeds, 150);
      expect(results[0].leeches, 20);
      expect(results[0].sizeBytes, (800.54 * 1024 * 1024).round());
      expect(results[0].source, 'LimeTorrents');
      expect(results[0].category, 'Music');

      expect(results[1].title, 'Pink Floyd - DSOTM [MP3 320kbps]');
      expect(results[1].seeds, 75);
      expect(results[1].leeches, 10);
    });

    test('returns empty list for HTML without results table', () {
      expect(
        LimeTorrentsIndexer.parseSearchPage('<html><body></body></html>'),
        isEmpty,
      );
    });

    test('skips rows with fewer than 5 cells', () {
      const html = '''
<table class="table2">
  <tbody>
    <tr>
      <td class="tdleft">only</td>
      <td class="tdnormal">three</td>
      <td class="tdnormal">cells</td>
    </tr>
  </tbody>
</table>
''';
      expect(LimeTorrentsIndexer.parseSearchPage(html), isEmpty);
    });

    test('skips rows with no link in first cell', () {
      const html = '''
<table class="table2">
  <tbody>
    <tr>
      <td class="tdleft">no link here</td>
      <td class="tdnormal">100 MB</td>
      <td class="tdnormal">Today</td>
      <td class="tdseed">5</td>
      <td class="tdleech">1</td>
    </tr>
  </tbody>
</table>
''';
      expect(LimeTorrentsIndexer.parseSearchPage(html), isEmpty);
    });

    test('skips rows whose href contains no 40-char hash', () {
      const html = '''
<table class="table2">
  <tbody>
    <tr>
      <td class="tdleft">
        <a href="/no-hash.html">Album Title</a>
      </td>
      <td class="tdnormal">100 MB</td>
      <td class="tdnormal">Today</td>
      <td class="tdseed">5</td>
      <td class="tdleech">1</td>
    </tr>
  </tbody>
</table>
''';
      expect(LimeTorrentsIndexer.parseSearchPage(html), isEmpty);
    });
  });

  group('LimeTorrentsIndexer.search (integration)', () {
    test('returns parsed SearchResults from mock HTTP', () async {
      final client = MockClient(
        (_) async => http.Response(_searchPageHtml, 200),
      );

      final indexer = LimeTorrentsIndexer(
        client: client,
        mirrors: ['https://www.limetorrents.lol'],
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(results[0].source, 'LimeTorrents');
      expect(results[0].category, 'Music');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient(
        (_) async => http.Response('Server Error', 500),
      );

      final indexer = LimeTorrentsIndexer(
        client: client,
        mirrors: ['https://www.limetorrents.lol'],
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer = LimeTorrentsIndexer(
        client: client,
        mirrors: ['https://www.limetorrents.lol'],
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

      final indexer = LimeTorrentsIndexer(
        client: client,
        mirrors: ['https://www.limetorrents.lol'],
      );
      await indexer.search('test');

      expect(userAgent, isNotNull);
      expect(userAgent, isNotEmpty);
    });

    test('URL contains encoded query in music path', () async {
      Uri? requestUri;
      final client = MockClient((request) async {
        requestUri = request.url;
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = LimeTorrentsIndexer(
        client: client,
        mirrors: ['https://www.limetorrents.lol'],
      );
      await indexer.search('pink floyd');

      expect(requestUri?.path, contains('pink%20floyd'));
      expect(requestUri?.path, contains('/music/'));
    });
  });

  group('LimeTorrentsIndexer mirror fallback', () {
    test('falls back to second mirror when first returns non-200', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (request.url.host == 'mirror1.example.com') {
          return http.Response('Blocked', 403);
        }
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = LimeTorrentsIndexer(
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

      final indexer = LimeTorrentsIndexer(
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

      final indexer = LimeTorrentsIndexer(
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
<div id="wrapper">
  <table class="table2">
    <thead>
      <tr>
        <th>Torrent Name</th>
        <th>Size</th>
        <th>Date</th>
        <th>Seeds</th>
        <th>Leeches</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td class="tdleft">
          <div class="tt-name">
            <a href="/Pink-Floyd-The-Wall-FLAC-torrent-ABCDEF1234567890ABCDEF1234567890ABCDEF12.html" class="namelink">
              Pink Floyd - The Wall [FLAC]
            </a>
          </div>
        </td>
        <td class="tdnormal">800.54 MB</td>
        <td class="tdnormal">2024-01-05</td>
        <td class="tdseed">150</td>
        <td class="tdleech">20</td>
      </tr>
      <tr>
        <td class="tdleft">
          <div class="tt-name">
            <a href="/Pink-Floyd-DSOTM-MP3-320kbps-torrent-FEDCBA0987654321FEDCBA0987654321FEDCBA09.html" class="namelink">
              Pink Floyd - DSOTM [MP3 320kbps]
            </a>
          </div>
        </td>
        <td class="tdnormal">120.30 MB</td>
        <td class="tdnormal">2024-01-12</td>
        <td class="tdseed">75</td>
        <td class="tdleech">10</td>
      </tr>
    </tbody>
  </table>
</div>
</body>
</html>
''';
