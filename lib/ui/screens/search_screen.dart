import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/search_result_tile.dart';

/// Local search query state for the UI.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Mock tracks for MVP until real search is connected.
final _mockTracks = [
  const Track(
      id: '1',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      duration: Duration(minutes: 5, seconds: 55),
      seeds: 1240,
      size: '12.4 MB'),
  const Track(
      id: '2',
      title: 'Stairway to Heaven',
      artist: 'Led Zeppelin',
      album: 'Led Zeppelin IV',
      duration: Duration(minutes: 8, seconds: 2),
      seeds: 890,
      size: '16.1 MB'),
  const Track(
      id: '3',
      title: 'Hotel California',
      artist: 'Eagles',
      album: 'Hotel California',
      duration: Duration(minutes: 6, seconds: 30),
      seeds: 1150,
      size: '13.0 MB'),
  const Track(
      id: '4',
      title: 'Comfortably Numb',
      artist: 'Pink Floyd',
      album: 'The Wall',
      duration: Duration(minutes: 6, seconds: 51),
      seeds: 760,
      size: '13.7 MB'),
];

/// Filtered mock results based on query.
final _filteredTracksProvider = Provider<List<Track>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  if (query.isEmpty) return _mockTracks;
  return _mockTracks.where((t) {
    return t.title.toLowerCase().contains(query) ||
        t.artist.toLowerCase().contains(query) ||
        t.album.toLowerCase().contains(query);
  }).toList();
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_filteredTracksProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Search',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
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
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text('No results found',
                        style: Theme.of(context).textTheme.bodyMedium))
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 80, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final track = results[index];
                      return SearchResultTile(
                        track: track,
                        onTap: () =>
                            ref.read(playerProvider.notifier).playTrack(track),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
