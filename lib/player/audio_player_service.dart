import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show protected, visibleForTesting;
import 'package:just_audio/just_audio.dart';

import 'track.dart';

/// Repeat mode for playback queue.
enum RepeatMode { off, one, all }

/// Snapshot of the current queue state.
class QueueState {
  final List<Track> tracks;
  final int currentIndex;
  final RepeatMode repeatMode;
  final bool shuffleEnabled;

  const QueueState({
    this.tracks = const [],
    this.currentIndex = -1,
    this.repeatMode = RepeatMode.off,
    this.shuffleEnabled = false,
  });

  Track? get currentTrack => currentIndex >= 0 && currentIndex < tracks.length
      ? tracks[currentIndex]
      : null;

  QueueState copyWith({
    List<Track>? tracks,
    int? currentIndex,
    RepeatMode? repeatMode,
    bool? shuffleEnabled,
  }) {
    return QueueState(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
    );
  }
}

/// Audio playback service — streaming from partial files, queue management,
/// repeat/shuffle, and system media controls.
///
/// Supports mp3, flac, ogg, and wav formats.
class AudioPlayerService {
  final AudioPlayer _player;

  /// Queue of tracks.
  List<Track> _queue = [];

  /// Current index in [_queue] (or the shuffle order if shuffle is on).
  int _currentIndex = -1;

  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffleEnabled = false;

  /// Shuffled index order — maps logical position to queue index.
  List<int> _shuffleOrder = [];

  final _queueController = StreamController<QueueState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  StreamSubscription<ProcessingState>? _processingStateSub;

  /// Create a new [AudioPlayerService].
  ///
  /// An optional [AudioPlayer] can be injected for testing.
  AudioPlayerService({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _listenForTrackCompletion();
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream of playback position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of track duration (null until loaded).
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of playing/paused state.
  Stream<bool> get playingStream => _player.playingStream;

  /// Stream of the current [ProcessingState].
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  /// Stream of queue state changes.
  Stream<QueueState> get queueStream => _queueController.stream;

  /// Stream of playback errors (file not found, decode failures, etc.).
  Stream<String> get errorStream => _errorController.stream;

  /// Current queue state snapshot.
  QueueState get queueState => QueueState(
        tracks: List.unmodifiable(_queue),
        currentIndex: _currentIndex,
        repeatMode: _repeatMode,
        shuffleEnabled: _shuffleEnabled,
      );

  /// Whether audio is currently playing.
  bool get playing => _player.playing;

  /// Current playback position.
  Duration get position => _player.position;

  /// Current track duration.
  Duration? get duration => _player.duration;

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  /// Play a track from its local [filePath].
  ///
  /// The file may still be downloading (progressive/streaming playback).
  /// Supported formats: mp3, flac, ogg, wav.
  Future<void> play(Track track, {String? filePath}) async {
    final path = filePath ?? track.filePath;
    if (path == null) {
      throw ArgumentError('No file path available for track: ${track.title}');
    }
    try {
      await _player.setFilePath(path);
      await _player.play();
    } catch (e) {
      _errorController.add('Failed to play "${track.title}": $e');
      rethrow;
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resume playback after a pause.
  Future<void> resume() async {
    await _player.play();
  }

  /// Seek to a [position] within the current track.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Stop playback and reset position.
  Future<void> stop() async {
    await _player.stop();
  }

  // ---------------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------------

  /// Replace the queue and start playing the track at [startIndex].
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = List.of(tracks);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    _rebuildShuffleOrder();
    _emitQueueState();
    await playCurrentTrack();
  }

  /// Play a single track, replacing the queue with just that track.
  Future<void> playTrack(Track track, {String? filePath}) async {
    _queue = [track];
    _currentIndex = 0;
    _rebuildShuffleOrder();
    _emitQueueState();
    await play(track, filePath: filePath);
  }

  /// Add a track to the end of the queue.
  void addToQueue(Track track) {
    _queue.add(track);
    if (_currentIndex < 0) _currentIndex = 0;
    _rebuildShuffleOrder();
    _emitQueueState();
  }

  /// Remove the track at [index] from the queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _rebuildShuffleOrder();
    _emitQueueState();
  }

  /// Reorder a track in the queue from [oldIndex] to [newIndex].
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex > _queue.length) return;
    final track = _queue.removeAt(oldIndex);
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _queue.insert(insertIndex, track);

    // Adjust current index to follow the currently-playing track.
    if (_currentIndex == oldIndex) {
      _currentIndex = insertIndex;
    } else if (oldIndex < _currentIndex && insertIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && insertIndex <= _currentIndex) {
      _currentIndex++;
    }
    _rebuildShuffleOrder();
    _emitQueueState();
  }

  /// Skip to the next track.
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    final nextIndex = _nextIndex();
    if (nextIndex == null) {
      await stop();
      return;
    }
    _currentIndex = nextIndex;
    _emitQueueState();
    await playCurrentTrack();
  }

  /// Skip to the previous track.
  ///
  /// If the current position is past 3 seconds, restarts the current track
  /// instead of going to the previous one.
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final prevIndex = _previousIndex();
    if (prevIndex == null) {
      await seek(Duration.zero);
      return;
    }
    _currentIndex = prevIndex;
    _emitQueueState();
    await playCurrentTrack();
  }

  /// Jump to a specific index in the queue.
  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _emitQueueState();
    await playCurrentTrack();
  }

  // ---------------------------------------------------------------------------
  // Repeat & shuffle
  // ---------------------------------------------------------------------------

  /// Set the repeat mode.
  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
    _emitQueueState();
  }

  /// Cycle through repeat modes: off → all → one → off.
  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
    }
    _emitQueueState();
  }

  /// Toggle shuffle on/off.
  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    _rebuildShuffleOrder();
    _emitQueueState();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Load and play the track at [_currentIndex]. Subclasses may override
  /// to avoid real audio decoding (e.g. in integration tests).
  @protected
  @visibleForTesting
  Future<void> playCurrentTrack() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    final track = _queue[_currentIndex];
    if (track.filePath == null) {
      _errorController.add('No file path for "${track.title}"');
      return;
    }
    try {
      await _player.setFilePath(track.filePath!);
      await _player.play();
    } catch (e) {
      _errorController.add('Failed to play "${track.title}": $e');
    }
  }

  void _listenForTrackCompletion() {
    _processingStateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onTrackCompleted();
      }
    });
  }

  Future<void> _onTrackCompleted() async {
    try {
      if (_repeatMode == RepeatMode.one) {
        await seek(Duration.zero);
        await _player.play();
        return;
      }
      await skipToNext();
    } catch (e) {
      _errorController.add('Auto-advance failed: $e');
    }
  }

  int? _nextIndex() {
    if (_queue.isEmpty) return null;
    if (_shuffleEnabled && _shuffleOrder.isNotEmpty) {
      final shufflePos = _shuffleOrder.indexOf(_currentIndex);
      if (shufflePos < _shuffleOrder.length - 1) {
        return _shuffleOrder[shufflePos + 1];
      }
      if (_repeatMode == RepeatMode.all) return _shuffleOrder.first;
      return null;
    }
    if (_currentIndex < _queue.length - 1) return _currentIndex + 1;
    if (_repeatMode == RepeatMode.all) return 0;
    return null;
  }

  int? _previousIndex() {
    if (_queue.isEmpty) return null;
    if (_shuffleEnabled && _shuffleOrder.isNotEmpty) {
      final shufflePos = _shuffleOrder.indexOf(_currentIndex);
      if (shufflePos > 0) return _shuffleOrder[shufflePos - 1];
      if (_repeatMode == RepeatMode.all) return _shuffleOrder.last;
      return null;
    }
    if (_currentIndex > 0) return _currentIndex - 1;
    if (_repeatMode == RepeatMode.all) return _queue.length - 1;
    return null;
  }

  void _rebuildShuffleOrder() {
    if (!_shuffleEnabled || _queue.isEmpty) {
      _shuffleOrder = [];
      return;
    }
    final rng = Random();
    _shuffleOrder = List.generate(_queue.length, (i) => i)..shuffle(rng);
    // Move the current index to the front so the current track stays.
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      _shuffleOrder.remove(_currentIndex);
      _shuffleOrder.insert(0, _currentIndex);
    }
  }

  void _emitQueueState() {
    _queueController.add(queueState);
  }

  /// Release all resources.
  Future<void> dispose() async {
    await _processingStateSub?.cancel();
    await _queueController.close();
    await _errorController.close();
    await _player.dispose();
  }
}
