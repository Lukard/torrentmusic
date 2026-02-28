import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/player_provider.dart';

/// Mock search results for MVP.
final _mockTracks = [
  const Track(
    id: '1',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    album: 'A Night at the Opera',
    duration: Duration(minutes: 5, seconds: 55),
    seeds: 1240,
    size: '12.4 MB',
  ),
  const Track(
    id: '2',
    title: 'Stairway to Heaven',
    artist: 'Led Zeppelin',
    album: 'Led Zeppelin IV',
    duration: Duration(minutes: 8, seconds: 2),
    seeds: 890,
    size: '16.1 MB',
  ),
  const Track(
    id: '3',
    title: 'Hotel California',
    artist: 'Eagles',
    album: 'Hotel California',
    duration: Duration(minutes: 6, seconds: 30),
    seeds: 1150,
    size: '13.0 MB',
  ),
  const Track(
    id: '4',
    title: 'Comfortably Numb',
    artist: 'Pink Floyd',
    album: 'The Wall',
    duration: Duration(minutes: 6, seconds: 51),
    seeds: 760,
    size: '13.7 MB',
  ),
  const Track(
    id: '5',
    title: 'Wish You Were Here',
    artist: 'Pink Floyd',
    album: 'Wish You Were Here',
    duration: Duration(minutes: 5, seconds: 34),
    seeds: 680,
    size: '11.2 MB',
  ),
  const Track(
    id: '6',
    title: 'Free Bird',
    artist: 'Lynyrd Skynyrd',
    album: 'Pronounced Leh-Nerd Skin-Nerd',
    duration: Duration(minutes: 9, seconds: 8),
    seeds: 520,
    size: '18.3 MB',
  ),
  const Track(
    id: '7',
    title: 'November Rain',
    artist: "Guns N' Roses",
    album: 'Use Your Illusion I',
    duration: Duration(minutes: 8, seconds: 57),
    seeds: 930,
    size: '17.9 MB',
  ),
  const Track(
    id: '8',
    title: 'Dream On',
    artist: 'Aerosmith',
    album: 'Aerosmith',
    duration: Duration(minutes: 4, seconds: 28),
    seeds: 410,
    size: '9.0 MB',
  ),
];

/// Search query state.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered search results based on query.
final searchResultsProvider = Provider<List<Track>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  if (query.isEmpty) return _mockTracks;
  return _mockTracks.where((t) {
    return t.title.toLowerCase().contains(query) ||
        t.artist.toLowerCase().contains(query) ||
        t.album.toLowerCase().contains(query);
  }).toList();
});
