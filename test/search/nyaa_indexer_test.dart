import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/nyaa_indexer.dart';

void main() {
  group('NyaaIndexer.parseSize', () {
    test('parses MiB', () {
      expect(
        NyaaIndexer.parseSize('800.5 MiB'),
        (800.5 * 1024 * 1024).round(),
      );
    });

    test('parses GiB', () {
      expect(
        NyaaIndexer.parseSize('1.2 GiB'),
        (1.2 * 1024 * 1024 * 1024).round(),
      );
    });

    test('parses plain MB (no i)', () {
      expect(NyaaIndexer.parseSize('350 MB'), 350 * 1024 * 1024);
    });

    test('parses KiB', () {
      expect(NyaaIndexer.parseSize('512 KiB'), 512 * 1024);
    });

    test('is case-insensitive', () {
      expect(NyaaIndexer.parseSize('100 mib'), 100 * 1024 * 1024);
    });

    test('returns 0 for empty string', () {
      expect(NyaaIndexer.parseSize(''), 0);
    });

    test('returns 0 for unrecognised format', () {
      expect(NyaaIndexer.parseSize('unknown'), 0);
    });
  });

  group('NyaaIndexer.parseSearchPage', () {
    test('extracts results from typical search HTML', () {
      final results = NyaaIndexer.parseSearchPage(_searchPageHtml);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(
        results[0].magnetUri,
        startsWith('magnet:?xt=urn:btih:ABCDEF1234567890'),
      );
      expect(results[0].seeds, 150);
      expect(results[0].leeches, 20);
      expect(results[0].sizeBytes, (800.5 * 1024 * 1024).round());
      expect(results[0].source, 'Nyaa');
      expect(results[0].category, 'Audio');

      expect(results[1].title, 'Pink Floyd - DSOTM [MP3 320kbps]');
      expect(results[1].seeds, 75);
      expect(results[1].leeches, 10);
      expect(results[1].sizeBytes, (120.3 * 1024 * 1024).round());
    });

    test('returns empty list for HTML without results table', () {
      expect(
        NyaaIndexer.parseSearchPage('<html><body></body></html>'),
        isEmpty,
      );
    });

    test('skips rows without a /view/ link', () {
      const html = '''
<table class="torrent-list">
  <tbody>
    <tr>
      <td><a href="/?c=2_0">cat</a></td>
      <td><a href="/download/1.torrent">dl</a></td>
      <td class="text-success">5</td>
      <td class="text-danger">1</td>
    </tr>
  </tbody>
</table>
''';
      expect(NyaaIndexer.parseSearchPage(html), isEmpty);
    });

    test('skips rows without a magnet link', () {
      const html = '''
<table class="torrent-list">
  <tbody>
    <tr>
      <td><a href="/?c=2_0">cat</a></td>
      <td><a href="/view/99" title="Album">Album</a></td>
      <td><a href="/download/99.torrent">dl</a></td>
      <td class="text-success">5</td>
      <td class="text-danger">1</td>
    </tr>
  </tbody>
</table>
''';
      expect(NyaaIndexer.parseSearchPage(html), isEmpty);
    });

    test('uses title attribute when present', () {
      const html = '''
<table class="torrent-list">
  <tbody>
    <tr>
      <td><a href="/?c=2_0">cat</a></td>
      <td>
        <a href="/view/1" title="My Album Title">link text differs</a>
      </td>
      <td>
        <a href="magnet:?xt=urn:btih:AAAA1111AAAA1111AAAA1111AAAA1111AAAA1111">mag</a>
      </td>
      <td>100 MiB</td>
      <td>2024-01-01</td>
      <td class="text-success">10</td>
      <td class="text-danger">2</td>
      <td>50</td>
    </tr>
  </tbody>
</table>
''';
      final results = NyaaIndexer.parseSearchPage(html);
      expect(results, hasLength(1));
      expect(results[0].title, 'My Album Title');
    });
  });

  group('NyaaIndexer.search (integration)', () {
    test('returns parsed SearchResults from mock HTTP', () async {
      final client = MockClient(
        (_) async => http.Response(_searchPageHtml, 200),
      );

      final indexer = NyaaIndexer(
        client: client,
        mirrors: ['https://nyaa.si'],
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(results[0].source, 'Nyaa');
      expect(results[0].category, 'Audio');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient(
        (_) async => http.Response('Server Error', 500),
      );

      final indexer = NyaaIndexer(
        client: client,
        mirrors: ['https://nyaa.si'],
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer = NyaaIndexer(
        client: client,
        mirrors: ['https://nyaa.si'],
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

      final indexer = NyaaIndexer(
        client: client,
        mirrors: ['https://nyaa.si'],
      );
      await indexer.search('test');

      expect(userAgent, isNotNull);
      expect(userAgent, isNotEmpty);
    });

    test('encodes query in URL', () async {
      Uri? requestUri;
      final client = MockClient((request) async {
        requestUri = request.url;
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = NyaaIndexer(
        client: client,
        mirrors: ['https://nyaa.si'],
      );
      await indexer.search('pink floyd');

      expect(requestUri?.queryParameters['q'], 'pink floyd');
      expect(requestUri?.queryParameters['c'], '2_0');
    });
  });

  group('NyaaIndexer mirror fallback', () {
    test('falls back to second mirror when first returns non-200', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (request.url.host == 'mirror1.example.com') {
          return http.Response('Blocked', 403);
        }
        return http.Response(_searchPageHtml, 200);
      });

      final indexer = NyaaIndexer(
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

      final indexer = NyaaIndexer(
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

      final indexer = NyaaIndexer(
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
<table class="torrent-list table table-striped tbody-highlight">
  <thead>
    <tr>
      <th colspan="2">Category</th>
      <th>Name</th>
      <th colspan="2">Links</th>
      <th>Size</th>
      <th>Date</th>
      <th title="Seeders">S</th>
      <th title="Leechers">L</th>
      <th title="Completed">C</th>
    </tr>
  </thead>
  <tbody>
    <tr class="default">
      <td><a href="/?c=2_0"><img src="/static/img/icons/music.png" alt="Audio - Lossless"></a></td>
      <td colspan="2">
        <a href="/view/1234567" title="Pink Floyd - The Wall [FLAC]">Pink Floyd - The Wall [FLAC]</a>
      </td>
      <td>
        <a href="/download/1234567.torrent"><i class="fa fa-fw fa-download"></i></a>
        <a href="magnet:?xt=urn:btih:ABCDEF1234567890ABCDEF1234567890ABCDEF12&amp;dn=Pink+Floyd&amp;tr=udp%3A%2F%2Ftracker.example.com%3A1337"><i class="fa fa-fw fa-magnet"></i></a>
      </td>
      <td>800.5 MiB</td>
      <td>2024-01-05 12:00</td>
      <td class="text-success">150</td>
      <td class="text-danger">20</td>
      <td>1234</td>
    </tr>
    <tr class="default">
      <td><a href="/?c=2_0"><img src="/static/img/icons/music.png" alt="Audio - MP3"></a></td>
      <td colspan="2">
        <a href="/view/7654321" title="Pink Floyd - DSOTM [MP3 320kbps]">Pink Floyd - DSOTM [MP3 320kbps]</a>
      </td>
      <td>
        <a href="/download/7654321.torrent"><i class="fa fa-fw fa-download"></i></a>
        <a href="magnet:?xt=urn:btih:FEDCBA0987654321FEDCBA0987654321FEDCBA09&amp;dn=Pink+Floyd+-+DSOTM&amp;tr=udp%3A%2F%2Ftracker.example.com%3A1337"><i class="fa fa-fw fa-magnet"></i></a>
      </td>
      <td>120.3 MiB</td>
      <td>2024-01-12 08:30</td>
      <td class="text-success">75</td>
      <td class="text-danger">10</td>
      <td>567</td>
    </tr>
  </tbody>
</table>
</body>
</html>
''';
