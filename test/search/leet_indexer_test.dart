import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/leet_indexer.dart';
import 'package:torrentmusic/search/search_result.dart';
import 'package:torrentmusic/search/search_service.dart';

void main() {
  group('LeetIndexer.parseSize', () {
    test('parses megabytes', () {
      expect(
        LeetIndexer.parseSize('350.5 MB'),
        (350.5 * 1024 * 1024).round(),
      );
    });

    test('parses gigabytes', () {
      expect(
        LeetIndexer.parseSize('1.2 GB'),
        (1.2 * 1024 * 1024 * 1024).round(),
      );
    });

    test('parses kilobytes', () {
      expect(LeetIndexer.parseSize('512 KB'), 512 * 1024);
    });

    test('parses terabytes', () {
      expect(
        LeetIndexer.parseSize('2 TB'),
        2 * 1024 * 1024 * 1024 * 1024,
      );
    });

    test('is case-insensitive', () {
      expect(LeetIndexer.parseSize('100 mb'), 100 * 1024 * 1024);
    });

    test('returns 0 for empty string', () {
      expect(LeetIndexer.parseSize(''), 0);
    });

    test('returns 0 for unrecognised format', () {
      expect(LeetIndexer.parseSize('unknown'), 0);
    });

    test('handles size followed by duplicate text (1337x quirk)', () {
      // 1337x size cells render as "350.5 MB<span>350.5</span>",
      // so .text produces "350.5 MB350.5".
      expect(
        LeetIndexer.parseSize('350.5 MB350.5'),
        (350.5 * 1024 * 1024).round(),
      );
    });
  });

  group('LeetIndexer.parseSearchPage', () {
    test('extracts results from typical search HTML', () {
      final results = LeetIndexer.parseSearchPage(_searchPageHtml);

      expect(results, hasLength(2));

      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(
        results[0].detailPath,
        '/torrent/12345/Pink-Floyd-The-Wall-FLAC/',
      );
      expect(results[0].seeds, 150);
      expect(results[0].leeches, 20);
      expect(results[0].sizeBytes, (800.5 * 1024 * 1024).round());

      expect(results[1].title, 'Pink Floyd - DSOTM [MP3 320]');
      expect(
        results[1].detailPath,
        '/torrent/67890/Pink-Floyd-DSOTM-MP3-320/',
      );
      expect(results[1].seeds, 75);
      expect(results[1].leeches, 10);
      expect(results[1].sizeBytes, (120.3 * 1024 * 1024).round());
    });

    test('returns empty list for HTML without results table', () {
      expect(
        LeetIndexer.parseSearchPage('<html><body></body></html>'),
        isEmpty,
      );
    });

    test('skips rows with missing name cell', () {
      const html = '''
<table class="table-list">
  <tbody>
    <tr><td class="coll-2">5</td></tr>
  </tbody>
</table>
''';
      expect(LeetIndexer.parseSearchPage(html), isEmpty);
    });

    test('skips rows where title link is absent', () {
      const html = '''
<table class="table-list">
  <tbody>
    <tr>
      <td class="coll-1 name">
        <a href="/sub/1/" class="icon">icon</a>
      </td>
      <td class="coll-2">5</td>
      <td class="coll-3">1</td>
      <td class="coll-4">100 MB</td>
    </tr>
  </tbody>
</table>
''';
      expect(LeetIndexer.parseSearchPage(html), isEmpty);
    });
  });

  group('LeetIndexer.parseDetailPage', () {
    test('extracts magnet URI from detail page', () {
      final magnet = LeetIndexer.parseDetailPage(_detailPageHtml);
      expect(magnet, startsWith('magnet:?xt=urn:btih:'));
      expect(magnet, contains('ABC123DEF456'));
    });

    test('returns null when no magnet link is present', () {
      expect(
        LeetIndexer.parseDetailPage(
          '<html><body><a href="/other">x</a></body></html>',
        ),
        isNull,
      );
    });
  });

  group('TorrentSearchService.isAudioContent', () {
    SearchResult makeResult(String title) => SearchResult(
          title: title,
          magnetUri: 'magnet:?xt=urn:btih:test',
          seeds: 1,
          leeches: 0,
          sizeBytes: 1024,
          source: '1337x',
        );

    test('accepts normal music titles', () {
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Pink Floyd - The Wall [FLAC]'),
        ),
        isTrue,
      );
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Radiohead - OK Computer (MP3 320)'),
        ),
        isTrue,
      );
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Bach Cello Suites ALAC'),
        ),
        isTrue,
      );
    });

    test('rejects video encodes', () {
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Concert.x264.BluRay'),
        ),
        isFalse,
      );
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Live.at.Pompeii.HEVC.mkv'),
        ),
        isFalse,
      );
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Music.Video.DVDRip.avi'),
        ),
        isFalse,
      );
    });

    test('rejects video resolution indicators', () {
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Concert.1080p.BluRay'),
        ),
        isFalse,
      );
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Live.Show.720p.WEB'),
        ),
        isFalse,
      );
      expect(
        TorrentSearchService.isAudioContent(
          makeResult('Performance.2160p.HDR'),
        ),
        isFalse,
      );
    });
  });

  group('LeetIndexer.search (integration)', () {
    test('returns assembled SearchResults from mock HTTP', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('category-search')) {
          return http.Response(_searchPageHtml, 200);
        }
        if (request.url.path.contains('/torrent/')) {
          return http.Response(_detailPageHtml, 200);
        }
        return http.Response('Not found', 404);
      });

      final indexer = LeetIndexer(
        client: client,
        baseUrl: 'https://1337x.to',
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      expect(results[0].title, 'Pink Floyd - The Wall [FLAC]');
      expect(results[0].magnetUri, startsWith('magnet:?xt=urn:btih:'));
      expect(results[0].source, '1337x');
      expect(results[0].category, 'Music');
      expect(results[0].seeds, 150);
      expect(results[1].title, 'Pink Floyd - DSOTM [MP3 320]');
    });

    test('returns empty list on HTTP error', () async {
      final client = MockClient(
        (_) async => http.Response('Server Error', 500),
      );

      final indexer = LeetIndexer(
        client: client,
        baseUrl: 'https://1337x.to',
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('returns empty list on network exception', () async {
      final client = MockClient((_) => throw Exception('no internet'));

      final indexer = LeetIndexer(
        client: client,
        baseUrl: 'https://1337x.to',
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('skips results when detail page has no magnet link', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('category-search')) {
          return http.Response(_searchPageHtml, 200);
        }
        // Detail pages return HTML without a magnet link.
        return http.Response(
          '<html><body><a href="/other">x</a></body></html>',
          200,
        );
      });

      final indexer = LeetIndexer(
        client: client,
        baseUrl: 'https://1337x.to',
      );
      final results = await indexer.search('pink floyd');

      expect(results, isEmpty);
    });
  });

  group('LeetIndexer mirror fallback', () {
    test('falls back to second mirror when first fails', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (request.url.host == 'mirror1.example.com') {
          return http.Response('Blocked', 403);
        }
        if (request.url.path.contains('category-search')) {
          return http.Response(_searchPageHtml, 200);
        }
        if (request.url.path.contains('/torrent/')) {
          return http.Response(_detailPageHtml, 200);
        }
        return http.Response('Not found', 404);
      });

      final indexer = LeetIndexer(
        client: client,
        mirrors: [
          'https://mirror1.example.com',
          'https://mirror2.example.com',
        ],
      );
      final results = await indexer.search('pink floyd');

      expect(results, hasLength(2));
      // First request to mirror1 failed, then mirror2 succeeded.
      expect(requestCount, greaterThan(1));
    });

    test('returns empty when all mirrors fail', () async {
      final client = MockClient(
        (_) async => http.Response('Blocked', 403),
      );

      final indexer = LeetIndexer(
        client: client,
        mirrors: [
          'https://mirror1.example.com',
          'https://mirror2.example.com',
        ],
      );
      final results = await indexer.search('test');

      expect(results, isEmpty);
    });

    test('falls back on network exception', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) throw Exception('timeout');
        if (request.url.path.contains('category-search')) {
          return http.Response(_searchPageHtml, 200);
        }
        if (request.url.path.contains('/torrent/')) {
          return http.Response(_detailPageHtml, 200);
        }
        return http.Response('Not found', 404);
      });

      final indexer = LeetIndexer(
        client: client,
        mirrors: [
          'https://mirror1.example.com',
          'https://mirror2.example.com',
        ],
      );
      final results = await indexer.search('test');

      expect(results, hasLength(2));
    });
  });
}

// ---------------------------------------------------------------------------
// HTML fixtures
// ---------------------------------------------------------------------------

const _searchPageHtml = '''
<html>
<body>
<table class="table-list table table-responsive table-striped">
  <thead>
    <tr>
      <th>Name</th><th>Se</th><th>Le</th><th>Time</th><th>Size</th><th>UL</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="coll-1 name">
        <a href="/sub/123/" class="icon"><i class="flaticon-music"></i></a>
        <a href="/torrent/12345/Pink-Floyd-The-Wall-FLAC/">Pink Floyd - The Wall [FLAC]</a>
      </td>
      <td class="coll-2 seeds">150</td>
      <td class="coll-3 leeches">20</td>
      <td class="coll-date">Oct. 5th '23</td>
      <td class="coll-4 size">800.5 MB<span class="seeds">800.5</span></td>
      <td class="coll-5 uploader">musicfan</td>
    </tr>
    <tr>
      <td class="coll-1 name">
        <a href="/sub/456/" class="icon"><i class="flaticon-music"></i></a>
        <a href="/torrent/67890/Pink-Floyd-DSOTM-MP3-320/">Pink Floyd - DSOTM [MP3 320]</a>
      </td>
      <td class="coll-2 seeds">75</td>
      <td class="coll-3 leeches">10</td>
      <td class="coll-date">Jan. 12th '24</td>
      <td class="coll-4 size">120.3 MB<span class="seeds">120.3</span></td>
      <td class="coll-5 uploader">audiophile</td>
    </tr>
  </tbody>
</table>
</body>
</html>
''';

const _detailPageHtml = '''
<html>
<body>
<div class="torrent-detail-page">
  <ul class="download-links-dontblock">
    <li>
      <a href="magnet:?xt=urn:btih:ABC123DEF456&dn=Pink+Floyd+-+The+Wall&tr=udp://tracker.example.com:1337">
        Magnet Download
      </a>
    </li>
  </ul>
  <a href="/download/12345/">Direct Download</a>
</div>
</body>
</html>
''';
