import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a playable track.
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final int seeds;
  final String size;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.seeds = 0,
    this.size = '',
  });
}

/// Player state.
class PlayerState {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const PlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlayerState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

/// Player state notifier — manages playback state.
class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(const PlayerState());

  void playTrack(Track track) {
    state = PlayerState(
      currentTrack: track,
      isPlaying: true,
      position: Duration.zero,
      duration: track.duration,
    );
  }

  void togglePlayPause() {
    if (state.currentTrack == null) return;
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void seek(Duration position) {
    state = state.copyWith(position: position);
  }

  void skipNext() {
    // TODO: implement queue-based skip
  }

  void skipPrevious() {
    // TODO: implement queue-based skip
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
