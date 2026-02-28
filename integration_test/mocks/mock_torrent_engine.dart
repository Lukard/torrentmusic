import 'dart:async';

import 'package:torrentmusic/core/torrent_engine.dart';

/// Mock torrent engine that simulates download progress for integration tests.
class MockTorrentEngine implements TorrentEngine {
  final Map<String, StreamController<TorrentStatus>> _controllers = {};
  final Map<String, List<TorrentFile>> _files = {};
  final Map<String, bool> _readyForPlayback = {};
  final List<String> _addedMagnets = [];

  /// If non-null, [addMagnet] will throw this error.
  Object? addMagnetError;

  /// If true, [isReadyForPlayback] always returns false (simulates timeout).
  bool neverReady = false;

  /// If non-null, status stream will emit an error state with this message.
  String? downloadErrorMessage;

  /// Number of calls to [addMagnet].
  int get addMagnetCallCount => _addedMagnets.length;

  /// Info hashes that were added.
  List<String> get addedMagnets => List.unmodifiable(_addedMagnets);

  @override
  Future<void> init({String? cachePath, int? maxConnections}) async {}

  @override
  Future<String> addMagnet(String magnetUri) async {
    if (addMagnetError != null) {
      throw addMagnetError!;
    }

    final infoHash = _extractInfoHash(magnetUri);
    _addedMagnets.add(infoHash);

    // Set up default files for this torrent.
    _files.putIfAbsent(infoHash, () {
      return [
        const TorrentFile(index: 0, path: '/tmp/mock/track.mp3', size: 5242880),
      ];
    });

    // Emit initial downloading status.
    _getController(infoHash).add(
      TorrentStatus(
        infoHash: infoHash,
        state: TorrentState.downloading,
        progress: 0.0,
        downloadSpeed: 512000,
        numPeers: 5,
        totalSize: 5242880,
      ),
    );

    return infoHash;
  }

  @override
  Future<List<TorrentFile>> listFiles(String infoHash) async {
    return _files[infoHash] ?? [];
  }

  @override
  Future<String> startStreaming(String infoHash, int fileIndex) async {
    final files = _files[infoHash] ?? [];
    if (fileIndex < 0 || fileIndex >= files.length) {
      throw RangeError('File index $fileIndex out of range');
    }

    // Mark as ready for playback after a short simulated delay.
    _readyForPlayback[infoHash] = true;

    // Emit buffering progress.
    _getController(infoHash).add(
      TorrentStatus(
        infoHash: infoHash,
        state: TorrentState.downloading,
        progress: 0.1,
        downloadSpeed: 1024000,
        numPeers: 5,
        totalSize: 5242880,
        downloadedSize: 524288,
      ),
    );

    return files[fileIndex].path;
  }

  @override
  Stream<TorrentStatus> watchStatus(String infoHash) {
    return _getController(infoHash).stream;
  }

  @override
  Future<bool> isReadyForPlayback(String infoHash, int fileIndex) async {
    if (neverReady) return false;
    return _readyForPlayback[infoHash] ?? false;
  }

  @override
  Future<void> pause(String infoHash) async {
    _getController(infoHash).add(
      TorrentStatus(
        infoHash: infoHash,
        state: TorrentState.paused,
        progress: 0.5,
      ),
    );
  }

  @override
  Future<void> resume(String infoHash) async {
    _getController(infoHash).add(
      TorrentStatus(
        infoHash: infoHash,
        state: TorrentState.downloading,
        progress: 0.5,
      ),
    );
  }

  @override
  Future<void> remove(String infoHash, {bool deleteFiles = false}) async {
    final controller = _controllers.remove(infoHash);
    await controller?.close();
    _files.remove(infoHash);
    _readyForPlayback.remove(infoHash);
  }

  @override
  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
  }

  /// Simulate download completing for a given info hash.
  void simulateDownloadComplete(String infoHash) {
    _getController(infoHash).add(
      TorrentStatus(
        infoHash: infoHash,
        state: TorrentState.complete,
        progress: 1.0,
        totalSize: 5242880,
        downloadedSize: 5242880,
      ),
    );
  }

  /// Simulate a download error for a given info hash.
  void simulateDownloadError(String infoHash, String message) {
    _getController(infoHash).add(
      TorrentStatus(
        infoHash: infoHash,
        state: TorrentState.error,
        progress: 0.0,
        errorMessage: message,
      ),
    );
  }

  /// Configure custom files for a specific info hash.
  void setFiles(String infoHash, List<TorrentFile> files) {
    _files[infoHash] = files;
  }

  StreamController<TorrentStatus> _getController(String infoHash) {
    return _controllers.putIfAbsent(
      infoHash,
      () => StreamController<TorrentStatus>.broadcast(),
    );
  }

  static String _extractInfoHash(String magnetUri) {
    final uri = Uri.parse(magnetUri);
    final xt = uri.queryParameters['xt'];
    if (xt != null && xt.startsWith('urn:btih:')) {
      return xt.substring('urn:btih:'.length).toLowerCase();
    }
    return magnetUri.hashCode.toRadixString(16);
  }
}
