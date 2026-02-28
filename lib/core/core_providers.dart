import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/player_provider.dart';
import 'aria2_engine.dart';
import 'playback_orchestrator.dart';
import 'torrent_engine.dart';

/// Provides the singleton [TorrentEngine] (backed by aria2c).
///
/// Call `ref.read(torrentEngineProvider).init()` at app startup.
final torrentEngineProvider = Provider<TorrentEngine>((ref) {
  final engine = Aria2Engine();
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
