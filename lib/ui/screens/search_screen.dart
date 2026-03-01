import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core_providers.dart';
import '../../core/playback_orchestrator.dart';
import '../../search/search_provider.dart';
import '../../search/search_result.dart';
import '../theme/app_colors.dart';

/// Committed search query — only updated on submit.
final _searchQueryProvider = StateProvider<String>((ref) => '');

/// Preparation state for user feedback (loading overlay, errors).
final _preparationStateProvider =
    StateProvider<PlaybackPreparation?>((ref) => null);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listen for preparation state changes from the orchestrator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orchestrator = ref.read(playbackOrchestratorProvider);
      orchestrator.preparationStream.listen((prep) {
        if (mounted) {
          ref.read(_preparationStateProvider.notifier).state = prep;
          // Clear the preparation state after a short delay on terminal states.
          if (prep.state == PlaybackPreparationState.playing ||
              prep.state == PlaybackPreparationState.error) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                ref.read(_preparationStateProvider.notifier).state = null;
              }
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      FocusScope.of(context).unfocus();
      ref.read(_searchQueryProvider.notifier).state = query;
    }
  }

  Future<void> _onResultTap(SearchResult result) async {
    final orchestrator = ref.read(playbackOrchestratorProvider);
    try {
      await orchestrator.playSearchResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback failed: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _onResultLongPress(SearchResult result) async {
    final orchestrator = ref.read(playbackOrchestratorProvider);
    try {
      await orchestrator.addToQueue(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${result.title}" to queue'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to queue: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final preparation = ref.watch(_preparationStateProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Search',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: InputDecoration(
                hintText: 'Search for songs, artists, albums...',
                hintStyle: const TextStyle(color: AppColors.subtle),
                prefixIcon: const Icon(Icons.search, color: AppColors.subtle),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.subtle),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          ref.read(_searchQueryProvider.notifier).state = '';
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Preparation status banner
          if (preparation != null) _buildPreparationBanner(preparation),
          // Search results
          Expanded(child: _buildResultsBody(query)),
        ],
      ),
    );
  }

  Widget _buildPreparationBanner(PlaybackPreparation prep) {
    final IconData icon;
    final String message;
    final Color color;

    switch (prep.state) {
      case PlaybackPreparationState.addingTorrent:
        icon = Icons.cloud_download_outlined;
        message = 'Adding torrent...';
        color = AppColors.accent;
      case PlaybackPreparationState.resolvingMetadata:
        icon = Icons.manage_search_rounded;
        message = 'Resolving metadata...';
        color = AppColors.accent;
      case PlaybackPreparationState.buffering:
        icon = Icons.hourglass_top_rounded;
        message = 'Buffering "${prep.track.title}"...';
        color = AppColors.accent;
      case PlaybackPreparationState.startingPlayback:
        icon = Icons.play_circle_outline_rounded;
        message = 'Starting playback...';
        color = AppColors.accent;
      case PlaybackPreparationState.playing:
        icon = Icons.check_circle_outline_rounded;
        message = 'Now playing "${prep.track.title}"';
        color = Colors.green;
      case PlaybackPreparationState.error:
        icon = Icons.error_outline_rounded;
        message = prep.errorMessage ?? 'An error occurred';
        color = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (prep.state == PlaybackPreparationState.buffering ||
              prep.state == PlaybackPreparationState.addingTorrent ||
              prep.state == PlaybackPreparationState.resolvingMetadata ||
              prep.state == PlaybackPreparationState.startingPlayback)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody(String query) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: AppColors.surfaceVariant,
            ),
            SizedBox(height: 16),
            Text(
              'Search for music to start streaming',
              style: TextStyle(color: AppColors.subtle),
            ),
          ],
        ),
      );
    }

    final resultsAsync = ref.watch(searchResultsProvider(query));

    return resultsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.subtle,
              ),
              const SizedBox(height: 16),
              Text(
                'Search failed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(searchResultsProvider(query)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.music_off_rounded,
                  size: 48,
                  color: AppColors.surfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No results found for "$query"',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 80, color: AppColors.divider),
          itemBuilder: (context, index) {
            final result = results[index];
            return _SearchResultTile(
              result: result,
              onTap: () => _onResultTap(result),
              onLongPress: () => _onResultLongPress(result),
            );
          },
        );
      },
    );
  }
}

/// A list tile displaying a [SearchResult] with torrent metadata.
class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
    this.onLongPress,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note, color: AppColors.accent, size: 24),
      ),
      title: Text(
        result.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${result.source} · ${result.category ?? "Music"}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatSize(result.sizeBytes),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_upward,
                size: 12,
                color: AppColors.subtle,
                semanticLabel: 'Seeds',
              ),
              const SizedBox(width: 2),
              Text(
                '${result.seeds}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_downward,
                size: 12,
                color: AppColors.subtle,
                semanticLabel: 'Leeches',
              ),
              const SizedBox(width: 2),
              Text(
                '${result.leeches}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
