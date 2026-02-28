/// Represents a playable track.
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final int seeds;
  final String size;

  /// Local file path once (partially) downloaded.
  final String? filePath;

  /// Magnet URI for the torrent source.
  final String? magnetUri;

  /// Index of this file within a multi-file torrent.
  final int? fileIndex;

  /// Audio bitrate in kbps.
  final int? bitrate;

  /// Audio format: mp3, flac, ogg, wav.
  final String? format;

  /// URL for album artwork.
  final String? artworkUrl;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.seeds = 0,
    this.size = '',
    this.filePath,
    this.magnetUri,
    this.fileIndex,
    this.bitrate,
    this.format,
    this.artworkUrl,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    int? seeds,
    String? size,
    String? filePath,
    String? magnetUri,
    int? fileIndex,
    int? bitrate,
    String? format,
    String? artworkUrl,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      seeds: seeds ?? this.seeds,
      size: size ?? this.size,
      filePath: filePath ?? this.filePath,
      magnetUri: magnetUri ?? this.magnetUri,
      fileIndex: fileIndex ?? this.fileIndex,
      bitrate: bitrate ?? this.bitrate,
      format: format ?? this.format,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Track && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($id, $title — $artist)';
}
