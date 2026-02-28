import 'dart:async';

/// State of a torrent download.
enum TorrentState {
  /// Resolving metadata from magnet link.
  metadata,

  /// Downloading file data.
  downloading,

  /// Download complete, seeding to peers.
  seeding,

  /// Download paused.
  paused,

  /// An error occurred.
  error,

  /// Download complete and stopped.
  complete,
}

/// Represents a file within a torrent.
class TorrentFile {
  /// Index of the file in the torrent.
  final int index;

  /// Relative path of the file within the torrent.
  final String path;

  /// Size in bytes.
  final int size;

  const TorrentFile({
    required this.index,
    required this.path,
    required this.size,
  });

  @override
  String toString() => 'TorrentFile(index: $index, path: $path, size: $size)';
}

/// Status snapshot of a torrent download.
class TorrentStatus {
  final String infoHash;
  final TorrentState state;
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final int totalSize;
  final int downloadedSize;
  final int numPeers;
  final String? errorMessage;

  const TorrentStatus({
    required this.infoHash,
    required this.state,
    required this.progress,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.totalSize = 0,
    this.downloadedSize = 0,
    this.numPeers = 0,
    this.errorMessage,
  });

  @override
  String toString() => 'TorrentStatus($infoHash, ${state.name}, '
      '${(progress * 100).toStringAsFixed(1)}%)';
}

/// Abstract torrent engine interface.
///
/// Implementations may wrap native libraries (libtorrent via FFI),
/// external processes (aria2c), or pure Dart BitTorrent clients.
abstract class TorrentEngine {
  /// Initialize the engine (create session, configure settings).
  Future<void> init({String? cachePath, int? maxConnections});

  /// Add a torrent from a magnet URI. Returns the info hash.
  Future<String> addMagnet(String magnetUri);

  /// List files in a resolved torrent.
  Future<List<TorrentFile>> listFiles(String infoHash);

  /// Start streaming a specific file (sequential download + priority).
  /// Returns the local file path that will be written to.
  Future<String> startStreaming(String infoHash, int fileIndex);

  /// Watch download status updates for a torrent.
  Stream<TorrentStatus> watchStatus(String infoHash);

  /// Check if enough data is buffered for audio playback.
  Future<bool> isReadyForPlayback(String infoHash, int fileIndex);

  /// Pause a torrent download.
  Future<void> pause(String infoHash);

  /// Resume a paused torrent.
  Future<void> resume(String infoHash);

  /// Remove a torrent and optionally delete downloaded files.
  Future<void> remove(String infoHash, {bool deleteFiles = false});

  /// Shut down the engine and release all resources.
  Future<void> dispose();
}
