import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_provider.dart';
import '../theme/app_colors.dart';

/// Full-screen now-playing view.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
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
                  ? _buildWideLayout(context, ref, player, track)
                  : _buildNarrowLayout(context, ref, player, track),
            ),
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
    Track track,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _albumArt(),
          const Spacer(flex: 2),
          _trackInfo(context, track),
          const SizedBox(height: 24),
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
                  const SizedBox(height: 32),
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

  Widget _progressBar(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
  ) {
    return Column(
      children: [
        SliderTheme(
          data: Theme.of(context).sliderTheme,
          child: Slider(
            value: player.position.inMilliseconds.toDouble(),
            max: player.duration.inMilliseconds > 0
                ? player.duration.inMilliseconds.toDouble()
                : 1.0,
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
          color: AppColors.onSurface,
          onPressed: () {},
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 36,
          onPressed: () => ref.read(playerProvider.notifier).skipPrevious(),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          backgroundColor: AppColors.accent,
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
          onPressed: () => ref.read(playerProvider.notifier).skipNext(),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.repeat_rounded),
          iconSize: 24,
          color: AppColors.onSurface,
          onPressed: () {},
        ),
      ],
    );
  }
}
