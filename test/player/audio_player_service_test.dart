import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrentmusic/player/audio_player_service.dart';
import 'package:torrentmusic/player/track.dart';

/// Tests for the player module — Track model, QueueState, and
/// AudioPlayerService queue management.
///
/// The actual [AudioPlayer] from just_audio requires platform channels, so
/// service-level tests use [_MockAudioPlayerService] which tests the queue
/// logic in isolation.

const _trackA = Track(
  id: 'a',
  title: 'Track A',
  artist: 'Artist A',
  album: 'Album A',
  duration: Duration(minutes: 3),
  filePath: '/tmp/a.mp3',
  format: 'mp3',
);
const _trackB = Track(
  id: 'b',
  title: 'Track B',
  artist: 'Artist B',
  album: 'Album B',
  duration: Duration(minutes: 4),
  filePath: '/tmp/b.flac',
  format: 'flac',
);
const _trackC = Track(
  id: 'c',
  title: 'Track C',
  artist: 'Artist C',
  album: 'Album C',
  duration: Duration(minutes: 5),
  filePath: '/tmp/c.ogg',
  format: 'ogg',
);
const _trackD = Track(
  id: 'd',
  title: 'Track D',
  artist: 'Artist D',
  album: 'Album D',
  duration: Duration(minutes: 2),
  filePath: '/tmp/d.wav',
  format: 'wav',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track model', () {
    test('equality is based on id', () {
      const t1 = Track(
        id: '1',
        title: 'Foo',
        artist: 'Bar',
        album: 'Baz',
        duration: Duration.zero,
      );
      const t2 = Track(
        id: '1',
        title: 'Different',
        artist: 'Different',
        album: 'Different',
        duration: Duration(seconds: 99),
      );
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
    });

    test('inequality when ids differ', () {
      const t1 = Track(
        id: '1',
        title: 'Same',
        artist: 'Same',
        album: 'Same',
        duration: Duration.zero,
      );
      const t2 = Track(
        id: '2',
        title: 'Same',
        artist: 'Same',
        album: 'Same',
        duration: Duration.zero,
      );
      expect(t1, isNot(equals(t2)));
    });

    test('copyWith creates a modified copy', () {
      final updated = _trackA.copyWith(title: 'New Title', bitrate: 320);
      expect(updated.title, 'New Title');
      expect(updated.bitrate, 320);
      expect(updated.id, _trackA.id);
      expect(updated.artist, _trackA.artist);
    });

    test('new fields are optional and backward-compatible', () {
      const minimal = Track(
        id: 'x',
        title: 'T',
        artist: 'A',
        album: 'Al',
        duration: Duration.zero,
      );
      expect(minimal.filePath, isNull);
      expect(minimal.magnetUri, isNull);
      expect(minimal.fileIndex, isNull);
      expect(minimal.bitrate, isNull);
      expect(minimal.format, isNull);
      expect(minimal.artworkUrl, isNull);
      expect(minimal.seeds, 0);
      expect(minimal.size, '');
    });

    test('toString includes id and title', () {
      expect(_trackA.toString(), contains('a'));
      expect(_trackA.toString(), contains('Track A'));
    });
  });

  group('QueueState', () {
    test('default state has no tracks', () {
      const qs = QueueState();
      expect(qs.tracks, isEmpty);
      expect(qs.currentIndex, -1);
      expect(qs.currentTrack, isNull);
      expect(qs.repeatMode, RepeatMode.off);
      expect(qs.shuffleEnabled, false);
    });

    test('currentTrack returns correct track', () {
      const qs = QueueState(
        tracks: [_trackA, _trackB],
        currentIndex: 1,
      );
      expect(qs.currentTrack, _trackB);
    });

    test('currentTrack is null when index is out of range', () {
      const qs = QueueState(tracks: [_trackA], currentIndex: 5);
      expect(qs.currentTrack, isNull);
    });

    test('currentTrack is null when index is negative', () {
      const qs = QueueState(tracks: [_trackA], currentIndex: -1);
      expect(qs.currentTrack, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      const original = QueueState(
        tracks: [_trackA],
        currentIndex: 0,
        repeatMode: RepeatMode.all,
        shuffleEnabled: true,
      );
      final modified = original.copyWith(repeatMode: RepeatMode.one);
      expect(modified.tracks, original.tracks);
      expect(modified.currentIndex, 0);
      expect(modified.repeatMode, RepeatMode.one);
      expect(modified.shuffleEnabled, true);
    });
  });

  group('RepeatMode enum', () {
    test('has three values', () {
      expect(RepeatMode.values.length, 3);
      expect(RepeatMode.values, contains(RepeatMode.off));
      expect(RepeatMode.values, contains(RepeatMode.one));
      expect(RepeatMode.values, contains(RepeatMode.all));
    });
  });

  group('AudioPlayerService queue management', () {
    late AudioPlayerService service;
    late List<QueueState> queueEvents;

    setUp(() {
      // Mock all just_audio platform channels so AudioPlayer can be created.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.audio_session'),
        (MethodCall methodCall) async => null,
      );
      service = AudioPlayerService();
      queueEvents = [];
      service.queueStream.listen(queueEvents.add);
    });

    tearDown(() async {
      await service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.audio_session'),
        null,
      );
    });

    test('addToQueue adds tracks', () {
      service.addToQueue(_trackA);
      service.addToQueue(_trackB);

      final qs = service.queueState;
      expect(qs.tracks.length, 2);
      expect(qs.tracks[0], _trackA);
      expect(qs.tracks[1], _trackB);
      expect(qs.currentIndex, 0);
    });

    test('removeFromQueue removes by index', () {
      service.addToQueue(_trackA);
      service.addToQueue(_trackB);
      service.addToQueue(_trackC);

      service.removeFromQueue(1);

      final qs = service.queueState;
      expect(qs.tracks.length, 2);
      expect(qs.tracks[0], _trackA);
      expect(qs.tracks[1], _trackC);
    });

    test('removeFromQueue with invalid index does nothing', () {
      service.addToQueue(_trackA);
      service.removeFromQueue(-1);
      service.removeFromQueue(5);
      expect(service.queueState.tracks.length, 1);
    });

    test('removeFromQueue adjusts currentIndex when removing before it', () {
      service.addToQueue(_trackA);
      service.addToQueue(_trackB);
      service.addToQueue(_trackC);

      // currentIndex starts at 0 after first add
      expect(service.queueState.currentIndex, 0);

      // Remove at 0 — the current track — index clamps to 0
      service.removeFromQueue(0);
      expect(service.queueState.currentIndex, 0);
      expect(service.queueState.tracks.length, 2);
      expect(service.queueState.tracks[0], _trackB);
    });

    test('reorderQueue moves tracks correctly', () {
      service.addToQueue(_trackA);
      service.addToQueue(_trackB);
      service.addToQueue(_trackC);

      // Move C from index 2 to index 0
      service.reorderQueue(2, 0);

      final qs = service.queueState;
      expect(qs.tracks[0], _trackC);
      expect(qs.tracks[1], _trackA);
      expect(qs.tracks[2], _trackB);
    });

    test('reorderQueue with invalid indices does nothing', () {
      service.addToQueue(_trackA);
      service.reorderQueue(-1, 0);
      service.reorderQueue(0, -1);
      expect(service.queueState.tracks, [_trackA]);
    });

    test('setRepeatMode updates mode', () {
      service.setRepeatMode(RepeatMode.all);
      expect(service.queueState.repeatMode, RepeatMode.all);

      service.setRepeatMode(RepeatMode.one);
      expect(service.queueState.repeatMode, RepeatMode.one);
    });

    test('cycleRepeatMode cycles off → all → one → off', () {
      expect(service.queueState.repeatMode, RepeatMode.off);

      service.cycleRepeatMode();
      expect(service.queueState.repeatMode, RepeatMode.all);

      service.cycleRepeatMode();
      expect(service.queueState.repeatMode, RepeatMode.one);

      service.cycleRepeatMode();
      expect(service.queueState.repeatMode, RepeatMode.off);
    });

    test('toggleShuffle toggles shuffle', () {
      expect(service.queueState.shuffleEnabled, false);

      service.toggleShuffle();
      expect(service.queueState.shuffleEnabled, true);

      service.toggleShuffle();
      expect(service.queueState.shuffleEnabled, false);
    });

    test('queue stream emits on changes', () async {
      service.addToQueue(_trackA);
      service.addToQueue(_trackB);

      // Let the stream deliver events.
      await Future<void>.delayed(Duration.zero);

      expect(queueEvents.length, 2);
      expect(queueEvents[0].tracks.length, 1);
      expect(queueEvents[1].tracks.length, 2);
    });

    test('all four supported formats can be queued', () {
      service.addToQueue(_trackA); // mp3
      service.addToQueue(_trackB); // flac
      service.addToQueue(_trackC); // ogg
      service.addToQueue(_trackD); // wav

      final qs = service.queueState;
      expect(qs.tracks.length, 4);
      expect(qs.tracks.map((t) => t.format), ['mp3', 'flac', 'ogg', 'wav']);
    });
  });
}
