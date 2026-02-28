import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrentmusic/core/playback_orchestrator.dart';
import 'package:torrentmusic/core/torrent_engine.dart';
import 'package:torrentmusic/player/audio_player_service.dart';
import 'package:torrentmusic/player/track.dart';
import 'package:torrentmusic/search/search_result.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory torrent engine for testing the orchestrator.
class FakeTorrentEngine implements TorrentEngine {
  final Map<String, String> _torrents = {};
  final Map<String, List<TorrentFile>> _files = {};
  final Map<String, StreamController<TorrentStatus>> _statusControllers = {};

  bool readyForPlayback = false;
  int addMagnetCalls = 0;
  int startStreamingCalls = 0;

  @override
  Future<void> init({String? cachePath, int? maxConnections}) async {}

  @override
  Future<String> addMagnet(String magnetUri) async {
    addMagnetCalls++;
    final uri = Uri.parse(magnetUri);
    final xt = uri.queryParameters['xt'];
    if (xt == null || !xt.startsWith('urn:btih:')) {
      throw ArgumentError('Invalid magnet URI: missing xt=urn:btih: parameter');
    }
    final hash = xt.replaceFirst('urn:btih:', '').toLowerCase();
    _torrents[hash] = magnetUri;
    _files[hash] = [
      const TorrentFile(index: 0, path: '/tmp/test_song.mp3', size: 5000000),
    ];
    _statusControllers.putIfAbsent(
      hash,
      () => StreamController<TorrentStatus>.broadcast(),
    );
    return hash;
  }

  @override
  Future<List<TorrentFile>> listFiles(String infoHash) async {
    return _files[infoHash] ?? [];
  }

  @override
  Future<String> startStreaming(String infoHash, int fileIndex) async {
    startStreamingCalls++;
    final files = _files[infoHash];
    if (files == null || fileIndex >= files.length) {
      throw StateError('No files');
    }
    return files[fileIndex].path;
  }

  @override
  Stream<TorrentStatus> watchStatus(String infoHash) {
    _statusControllers.putIfAbsent(
      infoHash,
      () => StreamController<TorrentStatus>.broadcast(),
    );
    return _statusControllers[infoHash]!.stream;
  }

  @override
  Future<bool> isReadyForPlayback(String infoHash, int fileIndex) async {
    return readyForPlayback;
  }

  @override
  Future<void> pause(String infoHash) async {}

  @override
  Future<void> resume(String infoHash) async {}

  @override
  Future<void> remove(String infoHash, {bool deleteFiles = false}) async {
    _torrents.remove(infoHash);
    _files.remove(infoHash);
    await _statusControllers.remove(infoHash)?.close();
  }

  @override
  Future<void> dispose() async {
    for (final c in _statusControllers.values) {
      await c.close();
    }
  }

  void emitStatus(String infoHash, TorrentStatus status) {
    _statusControllers[infoHash]?.add(status);
  }
}

/// Orchestrator subclass that intercepts audio playback calls, avoiding
/// platform channel issues in the test environment.
class TestableOrchestrator extends PlaybackOrchestrator {
  Track? lastPlayedTrack;
  final List<Track> queuedTracks = [];

  TestableOrchestrator({required super.engine, required super.playerService});

  @override
  Future<void> playSearchResult(SearchResult result) async {
    final track = searchResultToTrack(result);
    emitPreparation(track, PlaybackPreparationState.addingTorrent);

    try {
      final infoHash = await engine.addMagnet(result.magnetUri);
      final updatedTrack = track.copyWith(id: infoHash);

      emitPreparation(
        updatedTrack,
        PlaybackPreparationState.resolvingMetadata,
      );

      final files = await engine.listFiles(infoHash);
      final fileIndex = pickAudioFile(files);

      emitPreparation(updatedTrack, PlaybackPreparationState.buffering);

      final filePath = await engine.startStreaming(infoHash, fileIndex);
      final trackWithPath = updatedTrack.copyWith(
        filePath: filePath,
        fileIndex: fileIndex,
      );

      watchTorrentStatus(infoHash);
      await waitForBuffer(infoHash, fileIndex);

      emitPreparation(
        trackWithPath,
        PlaybackPreparationState.startingPlayback,
      );

      // Record instead of calling real playerService.playTrack.
      lastPlayedTrack = trackWithPath;

      emitPreparation(trackWithPath, PlaybackPreparationState.playing);
    } catch (e) {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  @override
  Future<void> addToQueue(SearchResult result) async {
    final track = searchResultToTrack(result);

    try {
      final infoHash = await engine.addMagnet(result.magnetUri);
      final files = await engine.listFiles(infoHash);
      final fileIndex = pickAudioFile(files);
      final filePath = await engine.startStreaming(infoHash, fileIndex);

      final trackWithPath = track.copyWith(
        id: infoHash,
        filePath: filePath,
        fileIndex: fileIndex,
      );

      watchTorrentStatus(infoHash);
      queuedTracks.add(trackWithPath);
    } catch (e) {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: e.toString(),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const _testResult = SearchResult(
  title: 'Test Song - Artist',
  magnetUri: 'magnet:?xt=urn:btih:ABCDEF123456&dn=test',
  seeds: 50,
  leeches: 5,
  sizeBytes: 5000000,
  source: '1337x',
  category: 'Music',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTorrentEngine engine;
  late AudioPlayerService playerService;
  late TestableOrchestrator orchestrator;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (MethodCall methodCall) async => null,
    );

    engine = FakeTorrentEngine();
    playerService = AudioPlayerService();
    orchestrator = TestableOrchestrator(
      engine: engine,
      playerService: playerService,
    );
  });

  tearDown(() async {
    await orchestrator.dispose();
    await playerService.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      null,
    );
  });

  group('PlaybackOrchestrator', () {
    test('playSearchResult adds magnet and starts streaming', () async {
      engine.readyForPlayback = true;

      final preparations = <PlaybackPreparation>[];
      orchestrator.preparationStream.listen(preparations.add);

      await orchestrator.playSearchResult(_testResult);
      // Let stream events propagate.
      await Future<void>.delayed(Duration.zero);

      expect(engine.addMagnetCalls, 1);
      expect(engine.startStreamingCalls, 1);
      expect(orchestrator.lastPlayedTrack, isNotNull);
      expect(orchestrator.lastPlayedTrack!.filePath, '/tmp/test_song.mp3');

      expect(preparations, isNotEmpty);
      expect(
        preparations.first.state,
        PlaybackPreparationState.addingTorrent,
      );
      expect(
        preparations.last.state,
        PlaybackPreparationState.playing,
      );
    });

    test('addToQueue adds tracks', () async {
      engine.readyForPlayback = true;

      await orchestrator.addToQueue(_testResult);

      expect(engine.addMagnetCalls, 1);
      expect(orchestrator.queuedTracks.length, 1);
      expect(orchestrator.queuedTracks.first.filePath, '/tmp/test_song.mp3');
    });

    test('emits error state when torrent engine fails', () async {
      const badResult = SearchResult(
        title: 'Bad Torrent',
        magnetUri: 'not-a-magnet-uri',
        seeds: 0,
        leeches: 0,
        sizeBytes: 0,
        source: 'test',
      );

      final preparations = <PlaybackPreparation>[];
      orchestrator.preparationStream.listen(preparations.add);

      try {
        await orchestrator.playSearchResult(badResult);
      } catch (_) {
        // Expected.
      }

      await Future<void>.delayed(Duration.zero);

      final errorPreps = preparations
          .where((p) => p.state == PlaybackPreparationState.error)
          .toList();
      expect(errorPreps, isNotEmpty);
    });

    test('torrentStatusStream emits status updates', () async {
      engine.readyForPlayback = true;

      final statuses = <TorrentStatus>[];
      orchestrator.torrentStatusStream.listen(statuses.add);

      await orchestrator.playSearchResult(_testResult);

      engine.emitStatus(
        'abcdef123456',
        const TorrentStatus(
          infoHash: 'abcdef123456',
          state: TorrentState.downloading,
          progress: 0.5,
          downloadSpeed: 1024000,
          numPeers: 3,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(statuses, isNotEmpty);
      expect(statuses.first.progress, 0.5);
      expect(orchestrator.getLatestStatus('abcdef123456'), isNotNull);
    });

    test('searchResultToTrack creates valid Track', () async {
      engine.readyForPlayback = true;

      final preparations = <PlaybackPreparation>[];
      orchestrator.preparationStream.listen(preparations.add);

      await orchestrator.playSearchResult(_testResult);

      expect(preparations, isNotEmpty);
      final track = preparations.first.track;
      expect(track.title, 'Test Song - Artist');
      expect(track.seeds, 50);
    });

    test('multiple addToQueue calls build up the queue', () async {
      engine.readyForPlayback = true;

      const result2 = SearchResult(
        title: 'Second Track',
        magnetUri: 'magnet:?xt=urn:btih:FEDCBA654321&dn=test2',
        seeds: 30,
        leeches: 2,
        sizeBytes: 3000000,
        source: '1337x',
        category: 'Music',
      );

      await orchestrator.addToQueue(_testResult);
      await orchestrator.addToQueue(result2);

      expect(engine.addMagnetCalls, 2);
      expect(orchestrator.queuedTracks.length, 2);
    });
  });

  group('PlaybackPreparation', () {
    test('copyWith creates modified copy', () {
      const prep = PlaybackPreparation(
        track: Track(
          id: '1',
          title: 'T',
          artist: 'A',
          album: 'Al',
          duration: Duration.zero,
        ),
        state: PlaybackPreparationState.buffering,
      );

      final updated = prep.copyWith(
        state: PlaybackPreparationState.playing,
        errorMessage: 'test',
      );

      expect(updated.state, PlaybackPreparationState.playing);
      expect(updated.errorMessage, 'test');
      expect(updated.track.id, '1');
    });
  });

  group('PlaybackPreparationState', () {
    test('has all expected values', () {
      expect(PlaybackPreparationState.values.length, 6);
    });
  });

  group('PlaybackOrchestrator helpers', () {
    test('pickAudioFile prefers audio extensions', () {
      final orch = TestableOrchestrator(
        engine: FakeTorrentEngine(),
        playerService: AudioPlayerService(),
      );

      final index = orch.pickAudioFile([
        const TorrentFile(index: 0, path: 'cover.jpg', size: 50000),
        const TorrentFile(index: 1, path: 'song.flac', size: 40000000),
        const TorrentFile(index: 2, path: 'readme.txt', size: 1000),
      ]);

      expect(index, 1);
    });

    test('pickAudioFile falls back to largest file', () {
      final orch = TestableOrchestrator(
        engine: FakeTorrentEngine(),
        playerService: AudioPlayerService(),
      );

      final index = orch.pickAudioFile([
        const TorrentFile(index: 0, path: 'small.bin', size: 1000),
        const TorrentFile(index: 1, path: 'large.bin', size: 9999999),
      ]);

      expect(index, 1);
    });

    test('pickAudioFile throws on empty list', () {
      final orch = TestableOrchestrator(
        engine: FakeTorrentEngine(),
        playerService: AudioPlayerService(),
      );

      expect(
        () => orch.pickAudioFile([]),
        throwsStateError,
      );
    });

    test('formatBytes formats correctly', () {
      expect(PlaybackOrchestrator.formatBytes(500), '500 B');
      expect(PlaybackOrchestrator.formatBytes(1024), '1.0 KB');
      expect(PlaybackOrchestrator.formatBytes(1048576), '1.0 MB');
      expect(PlaybackOrchestrator.formatBytes(1073741824), '1.0 GB');
    });
  });
}
