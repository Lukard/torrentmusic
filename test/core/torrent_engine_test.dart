import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:torrentmusic/core/aria2_engine.dart';
import 'package:torrentmusic/core/torrent_engine.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Model unit tests
  // ---------------------------------------------------------------------------

  group('TorrentFile', () {
    test('stores fields correctly', () {
      const file = TorrentFile(index: 0, path: 'song.mp3', size: 4096);
      expect(file.index, 0);
      expect(file.path, 'song.mp3');
      expect(file.size, 4096);
    });

    test('toString includes path', () {
      const file = TorrentFile(index: 1, path: 'track.flac', size: 2048);
      expect(file.toString(), contains('track.flac'));
    });
  });

  group('TorrentStatus', () {
    test('defaults for optional fields', () {
      const status = TorrentStatus(
        infoHash: 'abc123',
        state: TorrentState.downloading,
        progress: 0.5,
      );
      expect(status.downloadSpeed, 0);
      expect(status.uploadSpeed, 0);
      expect(status.totalSize, 0);
      expect(status.downloadedSize, 0);
      expect(status.numPeers, 0);
      expect(status.errorMessage, isNull);
    });

    test('toString shows percentage', () {
      const status = TorrentStatus(
        infoHash: 'abc123',
        state: TorrentState.downloading,
        progress: 0.756,
      );
      expect(status.toString(), contains('75.6%'));
    });

    test('all states are distinct', () {
      final states = TorrentState.values.toSet();
      expect(states.length, TorrentState.values.length);
    });
  });

  // ---------------------------------------------------------------------------
  // Aria2Engine static helpers
  // ---------------------------------------------------------------------------

  group('Aria2Engine.extractInfoHash', () {
    test('extracts lowercase hash', () {
      const magnet =
          'magnet:?xt=urn:btih:ABC123DEF456&dn=test&tr=udp://tracker.example';
      expect(Aria2Engine.extractInfoHash(magnet), 'abc123def456');
    });

    test('handles already-lowercase hash', () {
      const magnet = 'magnet:?xt=urn:btih:deadbeef0123';
      expect(Aria2Engine.extractInfoHash(magnet), 'deadbeef0123');
    });

    test('throws ArgumentError for non-magnet URI', () {
      expect(
        () => Aria2Engine.extractInfoHash('https://example.com/file.torrent'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for magnet without btih', () {
      expect(
        () => Aria2Engine.extractInfoHash('magnet:?dn=test'),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Aria2Engine with mock HTTP (no real aria2c required)
  // ---------------------------------------------------------------------------

  group('Aria2Engine with mock RPC', () {
    late List<Map<String, dynamic>> rpcLog;

    /// Build a mock HTTP client that responds to JSON-RPC requests.
    http.Client buildMockClient(
      Map<String, dynamic> Function(String method, List<dynamic>? params)
          handler,
    ) {
      return http_testing.MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final method = body['method'] as String;
        final params = body['params'] as List<dynamic>?;
        rpcLog.add({'method': method, 'params': params});

        final result = handler(method, params);
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], ...result}),
          200,
        );
      });
    }

    setUp(() {
      rpcLog = [];
    });

    test('addMagnet sends aria2.addUri and returns info hash', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-001'};
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16800, httpClient: client);

      const magnet =
          'magnet:?xt=urn:btih:AABBCCDD1122&dn=test&tr=udp://tracker';
      final hash = await engine.addMagnet(magnet);

      expect(hash, 'aabbccdd1122');
      expect(rpcLog.first['method'], 'aria2.addUri');
    });

    test('addMagnet deduplicates by info hash', () async {
      final client = buildMockClient((method, params) {
        return {'result': 'gid-001'};
      });

      final engine = Aria2Engine(rpcPort: 16801, httpClient: client);

      const magnet = 'magnet:?xt=urn:btih:AABB&dn=test';
      await engine.addMagnet(magnet);
      await engine.addMagnet(magnet);

      final addCalls =
          rpcLog.where((r) => r['method'] == 'aria2.addUri').length;
      expect(addCalls, 1);
    });

    test('watchStatus returns a broadcast stream', () {
      final engine = Aria2Engine(rpcPort: 16802);
      final stream = engine.watchStatus('somehash');
      expect(stream.isBroadcast, isTrue);
    });

    test('listFiles parses aria2 response', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-002'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'active', 'totalLength': '100'},
          };
        }
        if (method == 'aria2.getFiles') {
          return {
            'result': [
              {'path': '/tmp/song.mp3', 'length': '5000000'},
              {'path': '/tmp/cover.jpg', 'length': '50000'},
            ],
          };
        }
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16803, httpClient: client);

      // Populate internal state via the public API.
      const magnet = 'magnet:?xt=urn:btih:TESTHASH&dn=test';
      await engine.addMagnet(magnet);

      final files = await engine.listFiles('testhash');
      expect(files, hasLength(2));
      expect(files[0].path, '/tmp/song.mp3');
      expect(files[0].size, 5000000);
      expect(files[1].index, 1);
    });

    test('isReadyForPlayback returns true above threshold', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-003'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'active', 'totalLength': '100'},
          };
        }
        if (method == 'aria2.getFiles') {
          return {
            'result': [
              {
                'path': '/tmp/song.mp3',
                'length': '10000000',
                'completedLength': '600000', // 600 KB > 500 KB threshold
              },
            ],
          };
        }
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16804, httpClient: client);
      await engine.addMagnet('magnet:?xt=urn:btih:HASH1&dn=test');

      expect(await engine.isReadyForPlayback('hash1', 0), isTrue);
    });

    test('isReadyForPlayback returns false below threshold', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-004'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'active', 'totalLength': '100'},
          };
        }
        if (method == 'aria2.getFiles') {
          return {
            'result': [
              {
                'path': '/tmp/song.mp3',
                'length': '50000000',
                'completedLength': '100000', // 100 KB — below both thresholds
              },
            ],
          };
        }
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16805, httpClient: client);
      await engine.addMagnet('magnet:?xt=urn:btih:HASH2&dn=test');

      expect(await engine.isReadyForPlayback('hash2', 0), isFalse);
    });

    test('pause sends aria2.pause RPC', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-005'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'active', 'totalLength': '100'},
          };
        }
        if (method == 'aria2.pause') return {'result': 'gid-005'};
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16806, httpClient: client);
      await engine.addMagnet('magnet:?xt=urn:btih:HASH3&dn=test');
      await engine.pause('hash3');

      expect(rpcLog.any((r) => r['method'] == 'aria2.pause'), isTrue);
    });

    test('resume sends aria2.unpause RPC', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-006'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'paused', 'totalLength': '100'},
          };
        }
        if (method == 'aria2.unpause') return {'result': 'gid-006'};
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16807, httpClient: client);
      await engine.addMagnet('magnet:?xt=urn:btih:HASH4&dn=test');
      await engine.resume('hash4');

      expect(rpcLog.any((r) => r['method'] == 'aria2.unpause'), isTrue);
    });

    test('startStreaming validates index and returns file path', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-007'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'active', 'totalLength': '5000000'},
          };
        }
        if (method == 'aria2.getFiles') {
          return {
            'result': [
              {'path': '/tmp/song.mp3', 'length': '5000000'},
            ],
          };
        }
        if (method == 'aria2.changeOption') return {'result': 'OK'};
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16808, httpClient: client);
      await engine.addMagnet('magnet:?xt=urn:btih:HASH5&dn=test');

      final path = await engine.startStreaming('hash5', 0);
      expect(path, '/tmp/song.mp3');
      expect(
        rpcLog.any((r) => r['method'] == 'aria2.changeOption'),
        isTrue,
      );
    });

    test('startStreaming throws RangeError for invalid index', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-008'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'active', 'totalLength': '5000000'},
          };
        }
        if (method == 'aria2.getFiles') {
          return {
            'result': [
              {'path': '/tmp/song.mp3', 'length': '5000000'},
            ],
          };
        }
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16809, httpClient: client);
      await engine.addMagnet('magnet:?xt=urn:btih:HASH6&dn=test');

      expect(
        () => engine.startStreaming('hash6', 5),
        throwsA(isA<RangeError>()),
      );
      // changeOption should NOT have been called (validation first).
      expect(
        rpcLog.any((r) => r['method'] == 'aria2.changeOption'),
        isFalse,
      );
    });

    test('remove sends aria2.remove and cleans up state', () async {
      final client = buildMockClient((method, params) {
        if (method == 'aria2.addUri') return {'result': 'gid-009'};
        if (method == 'aria2.tellStatus') {
          return {
            'result': {'status': 'active', 'totalLength': '100'},
          };
        }
        if (method == 'aria2.remove') return {'result': 'gid-009'};
        return {'result': 'ok'};
      });

      final engine = Aria2Engine(rpcPort: 16810, httpClient: client);
      await engine.addMagnet('magnet:?xt=urn:btih:HASH7&dn=test');

      // Create a status watcher so we can verify it gets closed.
      final stream = engine.watchStatus('hash7');
      expect(stream.isBroadcast, isTrue);

      await engine.remove('hash7');
      expect(rpcLog.any((r) => r['method'] == 'aria2.remove'), isTrue);

      // After removal, the engine should not know about this hash.
      expect(
        () => engine.pause('hash7'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Integration test (requires aria2c installed)
  // ---------------------------------------------------------------------------

  group(
    'Aria2Engine integration',
    () {
      late Aria2Engine engine;

      setUp(() async {
        engine = Aria2Engine(rpcPort: 16900);
        await engine.init(
          cachePath:
              '${Directory.systemTemp.path}/torrentmusic_test_${DateTime.now().millisecondsSinceEpoch}',
        );
      });

      tearDown(() async {
        await engine.dispose();
      });

      test('init starts aria2c and RPC responds', () async {
        // If setUp succeeded, aria2c is running.
        // Verify watchStatus returns a valid stream.
        final stream = engine.watchStatus('nonexistent');
        expect(stream, isNotNull);
        expect(stream.isBroadcast, isTrue);
      });
    },
    skip: _aria2cAvailable() ? null : 'aria2c not installed',
  );
}

bool _aria2cAvailable() {
  try {
    final result = Process.runSync('which', ['aria2c']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
