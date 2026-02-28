/// Torrent engine — FFI bindings to libtorrent, download management,
/// piece prioritization, and cache control.
class TorrentEngine {
  /// Start downloading a torrent from the given magnet link or .torrent URL.
  Future<void> startDownload(String magnetOrUrl) async {
    // TODO: implement FFI call to libtorrent
    throw UnimplementedError();
  }

  /// Stop and clean up the active download.
  Future<void> stopDownload() async {
    // TODO: implement
    throw UnimplementedError();
  }

  /// Dispose of native resources.
  void dispose() {
    // TODO: release FFI handles
  }
}
