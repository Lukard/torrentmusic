# Torrent Engine Spec

## Overview
Wraps libtorrent (C++) via Dart FFI. Handles magnet resolution, peer management, progressive downloading with piece prioritization.

## Interface

```dart
abstract class TorrentEngine {
  /// Initialize the engine (create session, set settings)
  Future<void> init({String? cachePath, int? maxConnections});

  /// Add a torrent from magnet URI, returns info hash
  Future<String> addMagnet(String magnetUri);

  /// List files in a torrent
  Future<List<TorrentFile>> listFiles(String infoHash);

  /// Start streaming a specific file (enables sequential + priority)
  Future<String> startStreaming(String infoHash, int fileIndex);

  /// Get download status
  Stream<TorrentStatus> watchStatus(String infoHash);

  /// Check if enough data buffered for playback
  Future<bool> isReadyForPlayback(String infoHash, int fileIndex);

  /// Pause/resume
  Future<void> pause(String infoHash);
  Future<void> resume(String infoHash);

  /// Remove torrent and optionally delete files
  Future<void> remove(String infoHash, {bool deleteFiles = false});

  /// Shutdown engine
  Future<void> dispose();
}
```

## Key Behaviors

- On `startStreaming()`: set sequential download mode + boost first pieces priority
- Buffer threshold for playback: ~500KB or first 5% of file (whichever is smaller)
- Cache management: configurable max cache size, LRU eviction
- Support both magnet URIs and .torrent files

## libtorrent Settings

- `active_downloads`: 3
- `active_seeds`: 5  
- `connections_limit`: 200
- `enable_dht`: true
- `enable_lsd`: true
- `anonymous_mode`: true
