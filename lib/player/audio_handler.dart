import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_player_service.dart';
import 'track.dart';

/// Converts a [Track] to an [audio_service] [MediaItem].
MediaItem _trackToMediaItem(Track track) {
  return MediaItem(
    id: track.id,
    title: track.title,
    artist: track.artist,
    album: track.album,
    duration: track.duration,
    artUri: track.artworkUrl != null ? Uri.parse(track.artworkUrl!) : null,
  );
}

/// Maps just_audio [ProcessingState] to audio_service [AudioProcessingState].
AudioProcessingState _mapProcessingState(ProcessingState state) {
  return switch (state) {
    ProcessingState.idle => AudioProcessingState.idle,
    ProcessingState.loading => AudioProcessingState.loading,
    ProcessingState.buffering => AudioProcessingState.buffering,
    ProcessingState.ready => AudioProcessingState.ready,
    ProcessingState.completed => AudioProcessingState.completed,
  };
}

/// System media controls handler for notification and lock screen integration.
///
/// Bridges [AudioPlayerService] to [audio_service] so the OS can display
/// playback controls (notification shade, lock screen, headset buttons).
class TorrentMusicAudioHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  final AudioPlayerService _service;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Tracks the current processing state from just_audio so that
  /// [_updatePlaybackState] emits the correct value.
  AudioProcessingState _currentProcessingState = AudioProcessingState.idle;

  TorrentMusicAudioHandler(this._service) {
    // Forward position updates.
    _subs.add(
      _service.positionStream.listen((pos) {
        playbackState.add(
          playbackState.value.copyWith(
            updatePosition: pos,
          ),
        );
      }),
    );

    // Forward processing state from just_audio.
    _subs.add(
      _service.processingStateStream.listen((ps) {
        _currentProcessingState = _mapProcessingState(ps);
        _updatePlaybackState();
      }),
    );

    // Forward playing/paused state.
    _subs.add(
      _service.playingStream.listen((playing) {
        _updatePlaybackState(playing: playing);
      }),
    );

    // Forward queue changes.
    _subs.add(
      _service.queueStream.listen((qs) {
        queue.add(qs.tracks.map(_trackToMediaItem).toList());
        if (qs.currentTrack != null) {
          mediaItem.add(_trackToMediaItem(qs.currentTrack!));
        }
      }),
    );

    // Forward duration.
    _subs.add(
      _service.durationStream.listen((dur) {
        final current = mediaItem.value;
        if (current != null && dur != null) {
          mediaItem.add(current.copyWith(duration: dur));
        }
      }),
    );
  }

  void _updatePlaybackState({bool? playing}) {
    final isPlaying = playing ?? _service.playing;
    playbackState.add(
      playbackState.value.copyWith(
        playing: isPlaying,
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: _currentProcessingState,
        updatePosition: _service.position,
      ),
    );
  }

  @override
  Future<void> play() async => _service.resume();

  @override
  Future<void> pause() async => _service.pause();

  @override
  Future<void> stop() async => _service.stop();

  @override
  Future<void> seek(Duration position) async => _service.seek(position);

  @override
  Future<void> skipToNext() async => _service.skipToNext();

  @override
  Future<void> skipToPrevious() async => _service.skipToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async => _service.skipToIndex(index);

  /// Release subscriptions. Call when the app is shutting down.
  Future<void> release() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
  }
}
