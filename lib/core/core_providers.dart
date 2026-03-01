import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/player_provider.dart';
import 'aria2_engine.dart';
import 'dart_torrent_engine.dart';
import 'playback_orchestrator.dart';
import 'torrent_engine.dart';

/// Whether the current platform is a mobile OS (Android / iOS).
bool get _isMobilePlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Creates the appropriate [TorrentEngine] for the current platform.
///
/// - **Mobile (Android / iOS):** [DartTorrentEngine] — pure Dart, no external
///   binaries needed.
/// - **Desktop (macOS / Windows / Linux):** [Aria2Engine] — wraps the `aria2c`
///   subprocess via JSON-RPC. Falls back to [DartTorrentEngine] if aria2c is
///   not installed.
TorrentEngine createPlatformEngine() {
  if (_isMobilePlatform) {
    return DartTorrentEngine();
  }
  return Aria2Engine();
}

/// Provides the singleton [TorrentEngine].
///
/// Automatically selects the right implementation for the current platform.
/// Call `ref.read(torrentEngineProvider).init()` at app startup.
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final engine = createPlatformEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Provides the [PlaybackOrchestrator] singleton.
final playbackOrchestratorProvider = Provider<PlaybackOrchestrator>((ref) {
  final engine = ref.watch(torrentEngineProvider);
  final playerService = ref.watch(audioPlayerServiceProvider);
  final orchestrator = PlaybackOrchestrator(
    engine: engine,
    playerService: playerService,
  );
  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
});

/// Stream of [PlaybackPreparation] state changes for UI feedback.
final preparationStreamProvider = StreamProvider<PlaybackPreparation>((ref) {
  final orchestrator = ref.watch(playbackOrchestratorProvider);
  return orchestrator.preparationStream;
});

/// Stream of [TorrentStatus] updates for all active downloads.
final torrentStatusStreamProvider = StreamProvider<TorrentStatus>((ref) {
  final orchestrator = ref.watch(playbackOrchestratorProvider);
  return orchestrator.torrentStatusStream;
});
