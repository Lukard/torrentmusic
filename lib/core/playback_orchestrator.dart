import 'dart:async';

import 'package:flutter/foundation.dart';

import '../player/audio_player_service.dart';
import '../player/track.dart';
import '../search/search_result.dart';
import 'torrent_engine.dart';

/// Orchestration state for a single track being prepared for playback.
enum PlaybackPreparationState {
  /// Adding the magnet URI to the torrent engine.
  addingTorrent,

  /// Resolving torrent metadata (file list).
  resolvingMetadata,

  /// Downloading — waiting for enough buffer to start playback.
  buffering,

  /// Enough data buffered, starting audio playback.
  startingPlayback,

  /// Playing — audio is streaming from the partial file.
  playing,

  /// An error occurred during preparation.
  error,
}

/// Snapshot of orchestration progress for a single track.
class PlaybackPreparation {
  final Track track;
  final PlaybackPreparationState state;
  final String? errorMessage;
  final TorrentStatus? torrentStatus;

  const PlaybackPreparation({
    required this.track,
    required this.state,
    this.errorMessage,
    this.torrentStatus,
  });

  PlaybackPreparation copyWith({
    Track? track,
    PlaybackPreparationState? state,
    String? errorMessage,
    TorrentStatus? torrentStatus,
  }) {
    return PlaybackPreparation(
      track: track ?? this.track,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      torrentStatus: torrentStatus ?? this.torrentStatus,
    );
  }
}

/// Coordinates the end-to-end flow:
///   SearchResult → TorrentEngine (download) → AudioPlayerService (playback).
///
/// Call [playSearchResult] to kick off the pipeline for a single result, or
/// [addToQueue] to enqueue without immediately playing.
class PlaybackOrchestrator {
  /// The torrent engine used for downloads.
  @visibleForTesting
  final TorrentEngine engine;

  /// The audio player service used for playback.
  @visibleForTesting
  final AudioPlayerService playerService;

  final _preparationController =
      StreamController<PlaybackPreparation>.broadcast();

  /// Maps info hash → active status subscription.
  final Map<String, StreamSubscription<TorrentStatus>> _statusSubs = {};

  /// Maps info hash → latest torrent status.
  final Map<String, TorrentStatus> _latestStatus = {};

  final _torrentStatusController = StreamController<TorrentStatus>.broadcast();

  PlaybackOrchestrator({
    required this.engine,
    required this.playerService,
  });

  /// Stream of preparation state changes (for UI feedback).
  Stream<PlaybackPreparation> get preparationStream =>
      _preparationController.stream;

  /// Stream of all torrent status updates (for download progress UI).
  Stream<TorrentStatus> get torrentStatusStream =>
      _torrentStatusController.stream;

  /// Get the latest torrent status for an info hash.
  TorrentStatus? getLatestStatus(String infoHash) => _latestStatus[infoHash];

  /// Play a search result immediately (replaces current playback).
  ///
  /// Adds the magnet to the torrent engine, waits for enough buffer,
  /// then starts audio playback.
  Future<void> playSearchResult(SearchResult result) async {
    final track = searchResultToTrack(result);

    emitPreparation(track, PlaybackPreparationState.addingTorrent);

    try {
      final infoHash = await engine.addMagnet(result.magnetUri);
      final updatedTrack = track.copyWith(id: infoHash);

      // Subscribe to torrent status updates early to capture all events.
      watchTorrentStatus(infoHash);

      emitPreparation(
        updatedTrack,
        PlaybackPreparationState.resolvingMetadata,
      );

      // List files and pick the largest audio file.
      final files = await engine.listFiles(infoHash);
      final fileIndex = pickAudioFile(files);

      emitPreparation(updatedTrack, PlaybackPreparationState.buffering);

      // Start streaming (sequential download + priority).
      final filePath = await engine.startStreaming(infoHash, fileIndex);

      final trackWithPath = updatedTrack.copyWith(
        filePath: filePath,
        fileIndex: fileIndex,
      );

      // Wait for enough buffer to start playback.
      await waitForBuffer(infoHash, fileIndex);

      emitPreparation(
        trackWithPath,
        PlaybackPreparationState.startingPlayback,
      );

      // Start audio playback.
      await playerService.playTrack(trackWithPath, filePath: filePath);

      emitPreparation(trackWithPath, PlaybackPreparationState.playing);
    } on TorrentEngineException catch (e) {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: e.message,
      );
      rethrow;
    } on TimeoutException {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: 'Timed out waiting for torrent data. '
            'No peers may be available — try a result with more seeds.',
      );
      rethrow;
    } catch (e) {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: 'Failed to play track: $e',
      );
      rethrow;
    }
  }

  /// Add a search result to the playback queue without starting immediately.
  ///
  /// If nothing is playing, this will also begin playback.
  Future<void> addToQueue(SearchResult result) async {
    final track = searchResultToTrack(result);

    try {
      final infoHash = await engine.addMagnet(result.magnetUri);

      // Subscribe to torrent status updates early to capture all events.
      watchTorrentStatus(infoHash);

      final files = await engine.listFiles(infoHash);
      final fileIndex = pickAudioFile(files);
      final filePath = await engine.startStreaming(infoHash, fileIndex);

      final trackWithPath = track.copyWith(
        id: infoHash,
        filePath: filePath,
        fileIndex: fileIndex,
      );

      final isQueueEmpty = playerService.queueState.tracks.isEmpty;
      playerService.addToQueue(trackWithPath);

      // If nothing was playing, start playback once buffer is ready.
      if (isQueueEmpty) {
        await waitForBuffer(infoHash, fileIndex);
        await playerService.play(trackWithPath, filePath: filePath);
      }
    } on TorrentEngineException catch (e) {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: e.message,
      );
    } on TimeoutException {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: 'Timed out waiting for torrent data. '
            'No peers may be available — try a result with more seeds.',
      );
    } catch (e) {
      emitPreparation(
        track,
        PlaybackPreparationState.error,
        errorMessage: 'Failed to queue track: $e',
      );
    }
  }

  /// Convert a [SearchResult] into a [Track].
  ///
  /// Attempts to parse "Artist - Title" from [SearchResult.title].
  /// Falls back to "Unknown Artist" if no separator is found.
  @visibleForTesting
  Track searchResultToTrack(SearchResult result) {
    final parts = _parseArtistTitle(result.title);
    return Track(
      id: result.magnetUri.hashCode.toRadixString(16),
      title: parts.$2,
      artist: parts.$1,
      album: result.category ?? 'Unknown',
      duration: Duration.zero,
      seeds: result.seeds,
      size: formatBytes(result.sizeBytes),
      magnetUri: result.magnetUri,
    );
  }

  /// Try to split "Artist - Title" from a torrent name.
  /// Returns (artist, title). Falls back to ("Unknown Artist", original).
  static (String, String) _parseArtistTitle(String raw) {
    // Common separators in torrent names: " - ", " – ", " — "
    for (final sep in [' - ', ' – ', ' — ']) {
      final idx = raw.indexOf(sep);
      if (idx > 0) {
        final artist = raw.substring(0, idx).trim();
        final title = raw.substring(idx + sep.length).trim();
        if (artist.isNotEmpty && title.isNotEmpty) {
          return (artist, title);
        }
      }
    }
    return ('Unknown Artist', raw);
  }

  /// Pick the best audio file from a torrent's file list.
  ///
  /// Returns the index of the largest file (heuristic: audio files are
  /// typically the largest in a music torrent).
  @visibleForTesting
  int pickAudioFile(List<TorrentFile> files) {
    if (files.isEmpty) {
      throw StateError('Torrent contains no files');
    }

    // Prefer audio extensions, fall back to largest file.
    const audioExtensions = ['.mp3', '.flac', '.ogg', '.wav', '.m4a', '.aac'];
    final audioFiles = files.where((f) {
      final lower = f.path.toLowerCase();
      return audioExtensions.any(lower.endsWith);
    }).toList();

    final candidates = audioFiles.isNotEmpty ? audioFiles : files;
    candidates.sort((a, b) => b.size.compareTo(a.size));
    return candidates.first.index;
  }

  /// Poll the torrent engine until enough data is buffered for playback.
  @visibleForTesting
  Future<void> waitForBuffer(String infoHash, int fileIndex) async {
    const pollInterval = Duration(milliseconds: 500);
    const maxWait = Duration(minutes: 5);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      if (await engine.isReadyForPlayback(infoHash, fileIndex)) {
        return;
      }
      await Future<void>.delayed(pollInterval);
    }

    throw TimeoutException(
      'Timed out waiting for torrent buffer',
      maxWait,
    );
  }

  /// Subscribe to torrent status updates and forward them.
  @visibleForTesting
  void watchTorrentStatus(String infoHash) {
    if (_statusSubs.containsKey(infoHash)) return;

    // ignore: cancel_subscriptions
    final sub = engine.watchStatus(infoHash).listen((status) {
      _latestStatus[infoHash] = status;
      _torrentStatusController.add(status);
    });
    _statusSubs[infoHash] = sub;
  }

  /// Emit a preparation state change.
  @visibleForTesting
  void emitPreparation(
    Track track,
    PlaybackPreparationState state, {
    String? errorMessage,
  }) {
    _preparationController.add(
      PlaybackPreparation(
        track: track,
        state: state,
        errorMessage: errorMessage,
      ),
    );
  }

  /// Format bytes to a human-readable string.
  @visibleForTesting
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Release all resources.
  Future<void> dispose() async {
    for (final sub in _statusSubs.values) {
      await sub.cancel();
    }
    _statusSubs.clear();
    _latestStatus.clear();
    await _preparationController.close();
    await _torrentStatusController.close();
  }
}
