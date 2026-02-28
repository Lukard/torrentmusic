import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Mock audio player that simulates playback state for integration tests.
///
/// Wraps the real [AudioPlayer] interface by providing controllable streams
/// without actual audio decoding.
class MockAudioPlayerWrapper {
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(minutes: 3, seconds: 30);
  ProcessingState _processingState = ProcessingState.idle;

  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _processingStateController =
      StreamController<ProcessingState>.broadcast();

  Timer? _positionTimer;

  /// Whether audio is currently playing.
  bool get playing => _playing;

  /// Current playback position.
  Duration get position => _position;

  /// Current track duration.
  Duration get duration => _duration;

  Stream<bool> get playingStream => _playingController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<ProcessingState> get processingStateStream =>
      _processingStateController.stream;

  /// Simulate loading a file.
  Future<void> setFilePath(String path) async {
    _processingState = ProcessingState.loading;
    _processingStateController.add(_processingState);

    // Simulate short load time.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    _processingState = ProcessingState.ready;
    _processingStateController.add(_processingState);

    _position = Duration.zero;
    _positionController.add(_position);

    _durationController.add(_duration);
  }

  /// Simulate play.
  Future<void> play() async {
    _playing = true;
    _playingController.add(true);
    _processingState = ProcessingState.ready;
    _processingStateController.add(_processingState);
    _startPositionTimer();
  }

  /// Simulate pause.
  Future<void> pause() async {
    _playing = false;
    _playingController.add(false);
    _stopPositionTimer();
  }

  /// Simulate seek.
  Future<void> seek(Duration position) async {
    _position = position;
    _positionController.add(_position);
  }

  /// Simulate stop.
  Future<void> stop() async {
    _playing = false;
    _playingController.add(false);
    _position = Duration.zero;
    _positionController.add(_position);
    _processingState = ProcessingState.idle;
    _processingStateController.add(_processingState);
    _stopPositionTimer();
  }

  /// Set a custom duration.
  void setDuration(Duration d) {
    _duration = d;
    _durationController.add(d);
  }

  /// Simulate track completion.
  void simulateCompletion() {
    _playing = false;
    _playingController.add(false);
    _position = _duration;
    _positionController.add(_position);
    _processingState = ProcessingState.completed;
    _processingStateController.add(_processingState);
    _stopPositionTimer();
  }

  /// Release all resources.
  Future<void> dispose() async {
    _stopPositionTimer();
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _processingStateController.close();
  }

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_playing) {
        _position += const Duration(milliseconds: 200);
        _positionController.add(_position);
        if (_position >= _duration) {
          simulateCompletion();
        }
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
}
