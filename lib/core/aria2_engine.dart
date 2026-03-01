import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'torrent_engine.dart';

/// Torrent engine implementation backed by an aria2c subprocess.
///
/// Communicates with aria2c via its JSON-RPC interface.
/// Requires `aria2c` to be installed on the system (`brew install aria2`,
/// `apt install aria2`, etc.).
class Aria2Engine implements TorrentEngine {
  Aria2Engine({this.rpcPort = 6800, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final int rpcPort;
  final http.Client _http;

  Process? _process;
  String _downloadDir = '';
  int _rpcId = 0;

  /// Maps info hash → current aria2 GID.
  final Map<String, String> _hashToGid = {};

  /// Maps aria2 GID → info hash.
  final Map<String, String> _gidToHash = {};

  /// Active status stream controllers keyed by info hash.
  final Map<String, StreamController<TorrentStatus>> _statusControllers = {};

  Timer? _pollTimer;

  String get _rpcUrl => 'http://localhost:$rpcPort/jsonrpc';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> init({String? cachePath, int? maxConnections}) async {
    _downloadDir =
        cachePath ?? '${Directory.systemTemp.path}/torrentmusic_downloads';
    await Directory(_downloadDir).create(recursive: true);

    try {
      _process = await Process.start('aria2c', [
        '--enable-rpc',
        '--rpc-listen-port=$rpcPort',
        '--dir=$_downloadDir',
        '--seed-time=0',
        '--bt-save-metadata=true',
        '--enable-dht=true',
        '--enable-peer-exchange=true',
        '--bt-enable-lpd=true',
        '--follow-torrent=mem',
        if (maxConnections != null)
          '--max-connection-per-server=$maxConnections',
        '--quiet=true',
      ]);
    } on ProcessException catch (e) {
      throw TorrentEngineException(
        'aria2c is not installed or not found in PATH. '
        'Install it with: brew install aria2 (macOS), '
        'apt install aria2 (Linux), or download from https://aria2.github.io/ '
        '(Windows). On mobile platforms, use DartTorrentEngine instead.',
        cause: e,
      );
    }

    // Drain process output to prevent backpressure.
    unawaited(_process!.stdout.drain<void>());
    unawaited(_process!.stderr.drain<void>());

    // Wait for RPC to become available.
    var ready = false;
    for (var i = 0; i < 30; i++) {
      try {
        await _rpcCall('aria2.getVersion');
        ready = true;
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    if (!ready) {
      _process?.kill();
      _process = null;
      throw TorrentEngineException(
        'aria2c started but its RPC interface did not become available. '
        'Check that port $rpcPort is not already in use.',
      );
    }

    // Poll for status updates every second.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollStatuses(),
    );
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    for (final c in _statusControllers.values) {
      await c.close();
    }
    _statusControllers.clear();
    _hashToGid.clear();
    _gidToHash.clear();

    try {
      await _rpcCall('aria2.shutdown');
    } catch (_) {
      // Best-effort shutdown.
    }
    _process?.kill();
    _process = null;
    _http.close();
  }

  // ---------------------------------------------------------------------------
  // Torrent management
  // ---------------------------------------------------------------------------

  @override
  Future<String> addMagnet(String magnetUri) async {
    final infoHash = extractInfoHash(magnetUri);
    if (_hashToGid.containsKey(infoHash)) return infoHash;

    final gid = await _rpcCall('aria2.addUri', [
      [magnetUri],
      {'bt-prioritize-piece': 'head=10M', 'dir': _downloadDir},
    ]) as String;

    _hashToGid[infoHash] = gid;
    _gidToHash[gid] = infoHash;
    return infoHash;
  }

  @override
  Future<List<TorrentFile>> listFiles(String infoHash) async {
    final gid = await _resolveGid(infoHash);
    final result = await _rpcCall('aria2.getFiles', [gid]) as List<dynamic>;

    return result.asMap().entries.map((e) {
      final f = e.value as Map<String, dynamic>;
      return TorrentFile(
        index: e.key,
        path: (f['path'] as String?) ?? '',
        size: int.tryParse(f['length'] as String? ?? '0') ?? 0,
      );
    }).toList();
  }

  @override
  Future<String> startStreaming(String infoHash, int fileIndex) async {
    // Validate file index before sending RPC call.
    final files = await listFiles(infoHash);
    if (fileIndex < 0 || fileIndex >= files.length) {
      throw RangeError('File index $fileIndex out of range');
    }

    // Select only the target file and prioritize its head pieces.
    // aria2 uses 1-based file indexing.
    final gid = await _resolveGid(infoHash);
    await _rpcCall('aria2.changeOption', [
      gid,
      {
        'select-file': '${fileIndex + 1}',
        'bt-prioritize-piece': 'head=10M',
      },
    ]);

    return files[fileIndex].path;
  }

  @override
  Stream<TorrentStatus> watchStatus(String infoHash) {
    // Controllers are closed in dispose() and remove().
    // ignore: close_sinks
    final existing = _statusControllers[infoHash];
    if (existing != null) return existing.stream;
    // ignore: close_sinks
    final controller = StreamController<TorrentStatus>.broadcast();
    _statusControllers[infoHash] = controller;
    return controller.stream;
  }

  @override
  Future<bool> isReadyForPlayback(String infoHash, int fileIndex) async {
    final gid = await _resolveGid(infoHash);
    final result = await _rpcCall('aria2.getFiles', [gid]) as List<dynamic>;
    if (fileIndex < 0 || fileIndex >= result.length) return false;

    final file = result[fileIndex] as Map<String, dynamic>;
    final completed =
        int.tryParse(file['completedLength'] as String? ?? '0') ?? 0;
    final total = int.tryParse(file['length'] as String? ?? '0') ?? 0;

    if (total == 0) return false;

    // Ready when we have at least 500 KB or 5% of the file.
    const minBytes = 500 * 1024;
    final threshold = (total * 0.05).round();
    return completed >= minBytes || completed >= threshold;
  }

  @override
  Future<void> pause(String infoHash) async {
    final gid = await _resolveGid(infoHash);
    await _rpcCall('aria2.pause', [gid]);
  }

  @override
  Future<void> resume(String infoHash) async {
    final gid = await _resolveGid(infoHash);
    await _rpcCall('aria2.unpause', [gid]);
  }

  @override
  Future<void> remove(String infoHash, {bool deleteFiles = false}) async {
    final gid = await _resolveGid(infoHash);
    try {
      await _rpcCall('aria2.remove', [gid]);
    } catch (_) {
      // May already be stopped; try removing from completed results.
      try {
        await _rpcCall('aria2.removeDownloadResult', [gid]);
      } catch (_) {
        // Already gone.
      }
    }

    if (deleteFiles) {
      // aria2 downloads directly into _downloadDir; clean up any files.
      final dir = Directory(_downloadDir);
      if (dir.existsSync()) {
        // Only delete files that belong to this torrent — not the whole dir.
        // For the PoC we leave cleanup to the caller or a future improvement.
      }
    }

    _hashToGid.remove(infoHash);
    _gidToHash.remove(gid);
    final controller = _statusControllers.remove(infoHash);
    await controller?.close();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extract the info hash from a magnet URI.
  static String extractInfoHash(String magnetUri) {
    final uri = Uri.parse(magnetUri);
    final xt = uri.queryParameters['xt'];
    if (xt != null && xt.startsWith('urn:btih:')) {
      return xt.substring('urn:btih:'.length).toLowerCase();
    }
    throw ArgumentError('Invalid magnet URI: missing xt=urn:btih: parameter');
  }

  /// Resolve the current GID for an info hash, following metadata → download
  /// transitions that aria2c performs for magnet links.
  Future<String> _resolveGid(String infoHash) async {
    final gid = _hashToGid[infoHash];
    if (gid == null) {
      throw StateError('No torrent found for info hash: $infoHash');
    }

    try {
      final status =
          await _rpcCall('aria2.tellStatus', [gid]) as Map<String, dynamic>;
      final followedBy = status['followedBy'] as List<dynamic>?;
      if (followedBy != null && followedBy.isNotEmpty) {
        final newGid = followedBy.first as String;
        _hashToGid[infoHash] = newGid;
        _gidToHash.remove(gid);
        _gidToHash[newGid] = infoHash;
        return newGid;
      }
    } catch (_) {
      // GID may no longer exist; keep current mapping.
    }

    return gid;
  }

  /// Poll all tracked downloads and emit status updates.
  Future<void> _pollStatuses() async {
    for (final entry in Map<String, String>.of(_hashToGid).entries) {
      final infoHash = entry.key;
      // ignore: close_sinks
      final controller = _statusControllers[infoHash];
      if (controller == null || controller.isClosed) continue;

      try {
        final gid = await _resolveGid(infoHash);
        final result =
            await _rpcCall('aria2.tellStatus', [gid]) as Map<String, dynamic>;
        controller.add(_parseStatus(infoHash, result));
      } catch (_) {
        // Ignore transient polling errors.
      }
    }
  }

  TorrentStatus _parseStatus(String infoHash, Map<String, dynamic> raw) {
    final statusStr = raw['status'] as String? ?? '';
    final total = int.tryParse(raw['totalLength'] as String? ?? '0') ?? 0;
    final completed =
        int.tryParse(raw['completedLength'] as String? ?? '0') ?? 0;
    final dlSpeed = int.tryParse(raw['downloadSpeed'] as String? ?? '0') ?? 0;
    final ulSpeed = int.tryParse(raw['uploadSpeed'] as String? ?? '0') ?? 0;
    final connections = int.tryParse(raw['connections'] as String? ?? '0') ?? 0;

    TorrentState state;
    switch (statusStr) {
      case 'active':
        if (total == 0) {
          state = TorrentState.metadata;
        } else if (completed >= total) {
          state = TorrentState.seeding;
        } else {
          state = TorrentState.downloading;
        }
      case 'waiting' || 'paused':
        state = TorrentState.paused;
      case 'complete':
        state = TorrentState.complete;
      case 'error':
        state = TorrentState.error;
      case 'removed':
        state = TorrentState.complete;
      default:
        state = TorrentState.downloading;
    }

    return TorrentStatus(
      infoHash: infoHash,
      state: state,
      progress: total > 0 ? completed / total : 0.0,
      downloadSpeed: dlSpeed,
      uploadSpeed: ulSpeed,
      totalSize: total,
      downloadedSize: completed,
      numPeers: connections,
      errorMessage: raw['errorMessage'] as String?,
    );
  }

  /// Send a JSON-RPC request to the aria2c process.
  Future<dynamic> _rpcCall(String method, [List<dynamic>? params]) async {
    final id = '${++_rpcId}';
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    });

    final response = await _http.post(
      Uri.parse(_rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'aria2 RPC error: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      final error = json['error'] as Map<String, dynamic>;
      throw Exception('aria2 RPC: ${error['message']}');
    }
    return json['result'];
  }
}
