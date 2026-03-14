import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A [StreamAudioSource] that streams audio directly via youtube_explode_dart.
///
/// Bypasses URL extraction and proxying — avoids 403/502 errors from
/// signed URLs expiring or being rejected by intermediary proxies.
class YouTubeAudioSource extends StreamAudioSource {
  YouTubeAudioSource(this.videoId) : super(tag: 'youtube://$videoId');

  final String videoId;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final yt = YoutubeExplode();
    try {
      final manifest =
          await yt.videos.streamsClient.getManifest(VideoId(videoId));
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final totalBytes = streamInfo.size.totalBytes;

      final startByte = start ?? 0;
      final endByte = end ?? totalBytes;

      final rawStream = yt.videos.streamsClient.get(streamInfo);
      final slicedStream = _sliceStream(rawStream, startByte, endByte);

      return StreamAudioResponse(
        sourceLength: totalBytes,
        contentLength: endByte - startByte,
        offset: startByte,
        stream: slicedStream,
        contentType: 'audio/${streamInfo.container.name}',
      );
    } catch (e) {
      yt.close();
      rethrow;
    }
    // Note: yt.close() is not called on success because the stream is lazy —
    // the YoutubeExplode instance must stay alive while the stream is consumed.
    // It will be garbage-collected after the stream completes or is cancelled.
  }

  Stream<List<int>> _sliceStream(
    Stream<List<int>> source,
    int start,
    int end,
  ) async* {
    int position = 0;
    await for (final chunk in source) {
      if (position >= end) break;
      if (position + chunk.length <= start) {
        position += chunk.length;
        continue;
      }
      final chunkStart = (start - position).clamp(0, chunk.length);
      final chunkEnd = (end - position).clamp(0, chunk.length);
      position += chunk.length;
      if (chunkEnd > chunkStart) {
        yield chunk.sublist(chunkStart, chunkEnd);
      }
    }
  }
}
