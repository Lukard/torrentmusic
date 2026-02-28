import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torrentmusic/search/indexer_settings.dart';
import 'package:torrentmusic/search/leet_indexer.dart';
import 'package:torrentmusic/search/pirate_bay_indexer.dart';
import 'package:torrentmusic/search/search_service.dart';

void main() {
  group('TorrentSearchService multi-indexer', () {
    test('queries both indexers when both enabled', () async {
      final leetClient = MockClient((request) async {
        if (request.url.path.contains('category-search')) {
          return http.Response(_searchPageHtml, 200);
        }
        if (request.url.path.contains('/torrent/')) {
          return http.Response(_detailPageHtml, 200);
        }
        return http.Response('Not found', 404);
      });

      final pbClient = MockClient((request) async {
        return http.Response(_pirateBayJson, 200);
      });

      final service = TorrentSearchService(
        settings: const IndexerSettings(
          leetEnabled: true,
          pirateBayEnabled: true,
        ),
        leetIndexer:
            LeetIndexer(client: leetClient, baseUrl: 'https://1337x.to'),
        pirateBayIndexer:
            PirateBayIndexer(client: pbClient, baseUrl: 'https://apibay.org'),
      );

      final results = await service.search('pink floyd');
      expect(results, isNotEmpty);

      // Results should be sorted by seeds descending.
      for (var i = 0; i < results.length - 1; i++) {
        expect(results[i].seeds, greaterThanOrEqualTo(results[i + 1].seeds));
      }
    });

    test('queries only 1337x when PirateBay disabled', () async {
      final leetClient = MockClient((request) async {
        if (request.url.path.contains('category-search')) {
          return http.Response(_searchPageHtml, 200);
        }
        if (request.url.path.contains('/torrent/')) {
          return http.Response(_detailPageHtml, 200);
        }
        return http.Response('Not found', 404);
      });

      final service = TorrentSearchService(
        settings: const IndexerSettings(
          leetEnabled: true,
          pirateBayEnabled: false,
        ),
        leetIndexer:
            LeetIndexer(client: leetClient, baseUrl: 'https://1337x.to'),
      );

      final results = await service.search('pink floyd');
      expect(results, isNotEmpty);
      expect(results.every((r) => r.source == '1337x'), isTrue);
    });

    test('returns empty list when no indexers enabled', () async {
      final service = TorrentSearchService(
        settings: const IndexerSettings(
          leetEnabled: false,
          pirateBayEnabled: false,
        ),
      );

      final results = await service.search('test');
      expect(results, isEmpty);
    });

    test('deduplicates results with similar titles', () async {
      final pbClient = MockClient((request) async {
        // Return two results with nearly identical titles.
        return http.Response(
          '[{"name":"Pink Floyd The Wall","info_hash":"HASH1",'
          '"seeders":"100","leechers":"10","size":"500000000"},'
          '{"name":"Pink Floyd - The Wall","info_hash":"HASH2",'
          '"seeders":"50","leechers":"5","size":"500000000"}]',
          200,
        );
      });

      final service = TorrentSearchService(
        settings: const IndexerSettings(
          leetEnabled: false,
          pirateBayEnabled: true,
        ),
        pirateBayIndexer:
            PirateBayIndexer(client: pbClient, baseUrl: 'https://apibay.org'),
      );

      final results = await service.search('pink floyd');
      // Both normalize to the same key, so only the one with more seeds remains.
      expect(results, hasLength(1));
      expect(results[0].seeds, 100);
    });

    test('filters out video content', () async {
      final pbClient = MockClient((request) async {
        return http.Response(
          '[{"name":"Concert.1080p.BluRay.x264","info_hash":"HASH1",'
          '"seeders":"100","leechers":"10","size":"5000000000"},'
          '{"name":"Album FLAC Lossless","info_hash":"HASH2",'
          '"seeders":"50","leechers":"5","size":"500000000"}]',
          200,
        );
      });

      final service = TorrentSearchService(
        settings: const IndexerSettings(
          leetEnabled: false,
          pirateBayEnabled: true,
        ),
        pirateBayIndexer:
            PirateBayIndexer(client: pbClient, baseUrl: 'https://apibay.org'),
      );

      final results = await service.search('concert');
      expect(results, hasLength(1));
      expect(results[0].title, 'Album FLAC Lossless');
    });
  });
}

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
</div>
</body>
</html>
''';

const _pirateBayJson =
    '[{"name":"Pink Floyd - DSOTM MP3","info_hash":"PB123HASH",'
    '"seeders":"80","leechers":"12","size":"104857600"}]';
