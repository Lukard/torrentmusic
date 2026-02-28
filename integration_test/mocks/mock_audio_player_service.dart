import 'package:just_audio/just_audio.dart';
import 'package:torrentmusic/player/audio_player_service.dart';
import 'package:torrentmusic/player/track.dart';

import 'mock_audio_player.dart';

/// A test-only [AudioPlayerService] that delegates all audio operations to a
/// [MockAudioPlayerWrapper] instead of the real just_audio [AudioPlayer].
///
/// This prevents [PlayerException] errors from loading non-existent files
/// in integration tests while still exercising the full queue-management logic
/// inherited from the base class.
class MockAudioPlayerService extends AudioPlayerService {
  final MockAudioPlayerWrapper _mock = MockAudioPlayerWrapper();

  /// Expose the mock wrapper so tests can inspect or control state.
  MockAudioPlayerWrapper get mockPlayer => _mock;

  // ---------------------------------------------------------------------------
  // Stream / property overrides — return mock values instead of real player.
  // ---------------------------------------------------------------------------

  @override
  Stream<Duration> get positionStream => _mock.positionStream;

  @override
  Stream<Duration?> get durationStream => _mock.durationStream;

  @override
  Stream<bool> get playingStream => _mock.playingStream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _mock.processingStateStream;

  @override
  bool get playing => _mock.playing;

  @override
  Duration get position => _mock.position;

  @override
  Duration? get duration => _mock.duration;

  // ---------------------------------------------------------------------------
  // Playback overrides — use mock player instead of real audio decoding.
  // ---------------------------------------------------------------------------

  @override
  Future<void> play(Track track, {String? filePath}) async {
    await _mock.setFilePath(filePath ?? track.filePath ?? '');
    await _mock.play();
  }

  @override
  Future<void> pause() async => _mock.pause();

  @override
  Future<void> resume() async => _mock.play();

  @override
  Future<void> seek(Duration position) async => _mock.seek(position);

  @override
  Future<void> stop() async => _mock.stop();

  @override
  Future<void> playCurrentTrack() async {
    final qs = queueState;
    if (qs.currentIndex < 0 || qs.currentIndex >= qs.tracks.length) return;
    final track = qs.tracks[qs.currentIndex];
    if (track.filePath == null) return;
    await _mock.setFilePath(track.filePath!);
    await _mock.play();
  }

  @override
  Future<void> dispose() async {
    await _mock.dispose();
    await super.dispose();
  }
}
