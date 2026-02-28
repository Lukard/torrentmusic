import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core_providers.dart';
import '../../core/torrent_engine.dart';
import '../../player/audio_player_service.dart';
import '../../player/player_provider.dart';
import '../theme/app_colors.dart';

/// Full-screen now-playing view with download progress.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    // Watch torrent status stream for download progress.
    final torrentStatusAsync = ref.watch(torrentStatusStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          tooltip: 'Dismiss',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: track == null
          ? const Center(child: Text('Nothing playing'))
          : SafeArea(
              child: isWide
                  ? _buildWideLayout(
                      context,
                      ref,
                      player,
                      track,
                      torrentStatusAsync,
                    )
                  : _buildNarrowLayout(
                      context,
                      ref,
                      player,
                      track,
                      torrentStatusAsync,
                    ),
            ),
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
    Track track,
    AsyncValue<TorrentStatus> torrentStatusAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _albumArt(),
          const Spacer(flex: 2),
          _trackInfo(context, track),
          const SizedBox(height: 16),
          _downloadProgress(context, torrentStatusAsync),
          const SizedBox(height: 16),
          _progressBar(context, ref, player),
          const SizedBox(height: 24),
          _controls(ref, player),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
    Track track,
    AsyncValue<TorrentStatus> torrentStatusAsync,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Row(
          children: [
            const SizedBox(width: 48),
            Expanded(child: _albumArt()),
            const SizedBox(width: 48),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _trackInfo(context, track),
                  const SizedBox(height: 16),
                  _downloadProgress(context, torrentStatusAsync),
                  const SizedBox(height: 24),
                  _progressBar(context, ref, player),
                  const SizedBox(height: 32),
                  _controls(ref, player),
                ],
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _albumArt() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.album_rounded,
          size: 120,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _trackInfo(BuildContext context, Track track) {
    return Column(
      children: [
        Text(
          track.title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${track.artist} — ${track.album}',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _downloadProgress(
    BuildContext context,
    AsyncValue<TorrentStatus> torrentStatusAsync,
  ) {
    return torrentStatusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status.state == TorrentState.complete ||
            status.state == TorrentState.seeding) {
          return const SizedBox.shrink();
        }

        if (status.state == TorrentState.error) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 6),
                Text(
                  status.errorMessage ?? 'Download error',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: status.progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: AppColors.surfaceVariant,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accentLight),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(status.progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppColors.subtle, fontSize: 11),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.download_rounded,
                  size: 12,
                  color: AppColors.subtle,
                ),
                const SizedBox(width: 2),
                Text(
                  _formatSpeed(status.downloadSpeed),
                  style: const TextStyle(color: AppColors.subtle, fontSize: 11),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.people_outline_rounded,
                  size: 12,
                  color: AppColors.subtle,
                ),
                const SizedBox(width: 2),
                Text(
                  '${status.numPeers}',
                  style: const TextStyle(color: AppColors.subtle, fontSize: 11),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _progressBar(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
  ) {
    final maxMs = player.duration.inMilliseconds > 0
        ? player.duration.inMilliseconds.toDouble()
        : 1.0;
    return Column(
      children: [
        SliderTheme(
          data: Theme.of(context).sliderTheme,
          child: Slider(
            value: player.position.inMilliseconds.toDouble().clamp(0, maxMs),
            max: maxMs,
            semanticFormatterCallback: (value) {
              return _formatDuration(Duration(milliseconds: value.toInt()));
            },
            onChanged: (value) {
              ref
                  .read(playerProvider.notifier)
                  .seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(player.position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatDuration(player.duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controls(WidgetRef ref, PlayerState player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shuffle_rounded),
          iconSize: 24,
          color: player.shuffleEnabled ? AppColors.accent : AppColors.onSurface,
          tooltip: player.shuffleEnabled ? 'Shuffle on' : 'Shuffle off',
          onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 36,
          tooltip: 'Previous track',
          onPressed: () => ref.read(playerProvider.notifier).skipPrevious(),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          backgroundColor: AppColors.accent,
          tooltip: player.isPlaying ? 'Pause' : 'Play',
          onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
          child: Icon(
            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 36,
            color: AppColors.onAccent,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 36,
          tooltip: 'Next track',
          onPressed: () => ref.read(playerProvider.notifier).skipNext(),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(_repeatIcon(player.repeatMode)),
          iconSize: 24,
          color: player.repeatMode != RepeatMode.off
              ? AppColors.accent
              : AppColors.onSurface,
          tooltip: _repeatTooltip(player.repeatMode),
          onPressed: () => ref.read(playerProvider.notifier).cycleRepeatMode(),
        ),
      ],
    );
  }

  IconData _repeatIcon(RepeatMode mode) {
    return switch (mode) {
      RepeatMode.one => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
  }

  String _repeatTooltip(RepeatMode mode) {
    return switch (mode) {
      RepeatMode.off => 'Repeat off',
      RepeatMode.all => 'Repeat all',
      RepeatMode.one => 'Repeat one',
    };
  }
}
