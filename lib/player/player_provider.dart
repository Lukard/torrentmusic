import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_player_service.dart';
import 'track.dart';

// Re-export Track so existing UI imports continue to work.
export 'track.dart';

/// Player state exposed to the UI.
class PlayerState {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<Track> queue;
  final int currentIndex;
  final RepeatMode repeatMode;
  final bool shuffleEnabled;
  final ProcessingState processingState;

  const PlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
    this.repeatMode = RepeatMode.off,
    this.shuffleEnabled = false,
    this.processingState = ProcessingState.idle,
  });

  PlayerState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<Track>? queue,
    int? currentIndex,
    RepeatMode? repeatMode,
    bool? shuffleEnabled,
    ProcessingState? processingState,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      processingState: processingState ?? this.processingState,
    );
  }
}

/// Provides the [AudioPlayerService] singleton.
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Player state notifier — bridges [AudioPlayerService] streams to Riverpod.
class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayerService _service;
  final List<StreamSubscription<dynamic>> _subs = [];

  PlayerNotifier(this._service) : super(const PlayerState()) {
    _subs.add(
      _service.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      }),
    );
    _subs.add(
      _service.durationStream.listen((dur) {
        if (dur != null) state = state.copyWith(duration: dur);
      }),
    );
    _subs.add(
      _service.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
      }),
    );
    _subs.add(
      _service.processingStateStream.listen((ps) {
        state = state.copyWith(processingState: ps);
      }),
    );
    _subs.add(
      _service.queueStream.listen((qs) {
        state = state.copyWith(
          queue: qs.tracks,
          currentIndex: qs.currentIndex,
          currentTrack: qs.currentTrack,
          repeatMode: qs.repeatMode,
          shuffleEnabled: qs.shuffleEnabled,
        );
      }),
    );
  }

  /// Play a single track (replaces queue).
  void playTrack(Track track, {String? filePath}) {
    _service.playTrack(track, filePath: filePath);
  }

  /// Play a list of tracks starting at [startIndex].
  void playQueue(List<Track> tracks, {int startIndex = 0}) {
    _service.playQueue(tracks, startIndex: startIndex);
  }

  /// Toggle between play and pause.
  void togglePlayPause() {
    if (state.currentTrack == null) return;
    if (state.isPlaying) {
      _service.pause();
    } else {
      _service.resume();
    }
  }

  /// Seek to [position].
  void seek(Duration position) {
    _service.seek(position);
  }

  /// Skip to next track.
  void skipNext() {
    _service.skipToNext();
  }

  /// Skip to previous track.
  void skipPrevious() {
    _service.skipToPrevious();
  }

  /// Stop playback.
  void stop() {
    _service.stop();
  }

  /// Add a track to the end of the queue.
  void addToQueue(Track track) {
    _service.addToQueue(track);
  }

  /// Remove the track at [index] from the queue.
  void removeFromQueue(int index) {
    _service.removeFromQueue(index);
  }

  /// Reorder a track in the queue.
  void reorderQueue(int oldIndex, int newIndex) {
    _service.reorderQueue(oldIndex, newIndex);
  }

  /// Toggle shuffle mode.
  void toggleShuffle() {
    _service.toggleShuffle();
  }

  /// Cycle repeat mode: off → all → one → off.
  void cycleRepeatMode() {
    _service.cycleRepeatMode();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}

/// Primary player provider — used by UI widgets.
final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return PlayerNotifier(service);
});
