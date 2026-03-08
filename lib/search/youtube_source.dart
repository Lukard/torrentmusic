import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    hide SearchResult;

import 'search_result.dart';

/// Abstract delegate that performs YouTube searches.
///
/// Extracted so that [YouTubeSource] can be tested without real network calls.
abstract class YoutubeSearchDelegate {
  /// Searches YouTube for [query] and returns mapped [SearchResult]s.
  Future<List<SearchResult>> search(String query);
}

/// Default [YoutubeSearchDelegate] backed by [YoutubeExplode].
class YoutubeExplodeDelegate implements YoutubeSearchDelegate {
  YoutubeExplodeDelegate() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  @override
  Future<List<SearchResult>> search(String query) async {
    final videos = await _yt.search.search('$query music');
    return videos
        .map(
          (v) => SearchResult(
            title: '${v.author} - ${v.title}',
            magnetUri: 'youtube://${v.id.value}',
            seeds: 0,
            leeches: 0,
            sizeBytes: 0,
            source: YouTubeSource.sourceName,
            category: 'YouTube',
            thumbnailUrl: v.thumbnails.mediumResUrl,
          ),
        )
        .toList();
  }

  /// Resolves the audio stream URL for a YouTube video ID.
  ///
  /// Audio stream URLs expire quickly — call this lazily at play time, not at
  /// search time. Returns `null` if no audio-only stream is available.
  Future<Uri?> resolveAudioStreamUrl(String videoId) async {
    try {
      final manifest =
          await _yt.videos.streamsClient.getManifest(VideoId(videoId));
      final stream = manifest.audioOnly.withHighestBitrate();
      return stream.url;
    } catch (_) {
      return null;
    }
  }
}

/// Searches YouTube for music and returns [SearchResult]s with a
/// `youtube://<videoId>` [SearchResult.magnetUri] that the audio player
/// resolves lazily at play time.
class YouTubeSource {
  /// Creates a [YouTubeSource].
  ///
  /// An optional [delegate] can be injected for testing.
  YouTubeSource({YoutubeSearchDelegate? delegate})
      : _delegate = delegate ?? YoutubeExplodeDelegate();

  final YoutubeSearchDelegate _delegate;

  /// Source name reported in [SearchResult.source].
  static const String sourceName = 'YouTube';

  /// Per-search timeout — matches the torrent indexer default.
  static const _searchTimeout = Duration(seconds: 15);

  /// Searches YouTube for music matching [query].
  ///
  /// Returns an empty list on any error or timeout rather than propagating
  /// exceptions, consistent with the torrent indexer pattern.
  Future<List<SearchResult>> search(String query) async {
    try {
      return await _delegate.search(query).timeout(_searchTimeout);
    } catch (_) {
      return [];
    }
  }
}
