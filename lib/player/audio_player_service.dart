import 'package:just_audio/just_audio.dart';

/// Audio playback service — streaming from partial files, queue management,
/// repeat/shuffle, and system media controls.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Play audio from the given file path.
  Future<void> play(String filePath) async {
    await _player.setFilePath(filePath);
    await _player.play();
  }

  /// Pause playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Stop playback and reset position.
  Future<void> stop() async {
    await _player.stop();
  }

  /// Release resources.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
