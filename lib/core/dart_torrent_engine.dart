import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:b_encode_decode/b_encode_decode.dart';
import 'package:dtorrent_parser/dtorrent_parser.dart' hide TorrentFile;
// ignore: implementation_imports
import 'package:dtorrent_parser/src/torrent_parser.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;
import 'package:events_emitter2/events_emitter2.dart';

import 'torrent_engine.dart';

/// Pure-Dart torrent engine backed by [dtorrent_task_v2].
///
/// Works on all platforms (Android, iOS, macOS, Windows, Linux) — no external
/// binary required.  Uses DHT + BEP 9 (metadata exchange) to resolve magnet
/// URIs, then downloads with sequential piece selection for streaming.
class DartTorrentEngine implements TorrentEngine {
  String _downloadDir = '';

  /// Active torrent tasks keyed by info hash.
  final Map<String, dt.TorrentTask> _tasks = {};

  /// Parsed torrent models keyed by info hash.
  final Map<String, Torrent> _models = {};

  /// Active status stream controllers keyed by info hash.
  final Map<String, StreamController<TorrentStatus>> _statusControllers = {};

  /// Event listeners keyed by info hash (so we can dispose them).
  final Map<String, EventsListener<dt.TaskEvent>> _listeners = {};

  Timer? _pollTimer;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> init({String? cachePath, int? maxConnections}) async {
    _downloadDir =
        cachePath ?? '${Directory.systemTemp.path}/torrentmusic_downloads';
    await Directory(_downloadDir).create(recursive: true);

    // Poll for status updates every second (same cadence as Aria2Engine).
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollStatuses(),
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _pollTimer?.cancel();

    for (final entry in _tasks.entries) {
      try {
        await entry.value.stop();
      } catch (_) {}
    }
    _tasks.clear();
    _models.clear();

    for (final listener in _listeners.values) {
      unawaited(listener.dispose());
    }
    _listeners.clear();

    for (final c in _statusControllers.values) {
      unawaited(c.close());
    }
    _statusControllers.clear();
  }

  // ---------------------------------------------------------------------------
  // Torrent management
  // ---------------------------------------------------------------------------

  @override
  Future<String> addMagnet(String magnetUri) async {
    final infoHash = _extractInfoHash(magnetUri);
    if (_tasks.containsKey(infoHash)) return infoHash;

    // Phase 1: Download metadata from DHT + peers via BEP 9.
    final torrent = await _downloadMetadata(infoHash);
    _models[infoHash] = torrent;

    // Phase 2: Create and start a download task with sequential piece
    // selection (stream = true).
    final task = dt.TorrentTask.newTask(torrent, _downloadDir, true);
    _tasks[infoHash] = task;

    // Subscribe to task events so we can update status and detect completion.
    final listener = task.createListener();
    _listeners[infoHash] = listener;
    listener
      ..on<dt.TaskCompleted>((_) => _emitStatus(infoHash))
      ..on<dt.StateFileUpdated>((_) => _emitStatus(infoHash))
      ..on<dt.TaskStopped>((_) => _emitStatus(infoHash));

    await task.start();
    return infoHash;
  }

  @override
  Future<List<TorrentFile>> listFiles(String infoHash) async {
    final model = _models[infoHash];
    if (model == null) {
      throw StateError('No torrent metadata for info hash: $infoHash');
    }

    return model.files.asMap().entries.map((e) {
      final f = e.value;
      return TorrentFile(
        index: e.key,
        path: f.name,
        size: f.length,
      );
    }).toList();
  }

  @override
  Future<String> startStreaming(String infoHash, int fileIndex) async {
    final model = _models[infoHash];
    if (model == null) {
      throw StateError('No torrent found for info hash: $infoHash');
    }

    final files = model.files;
    if (fileIndex < 0 || fileIndex >= files.length) {
      throw RangeError('File index $fileIndex out of range');
    }

    // The dtorrent_task library already uses SequentialPieceSelector when
    // stream=true.  We return the expected local file path.
    final file = files[fileIndex];
    return '$_downloadDir/${file.path}';
  }

  @override
  Stream<TorrentStatus> watchStatus(String infoHash) {
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
    final task = _tasks[infoHash];
    final model = _models[infoHash];
    if (task == null || model == null) return false;

    final files = model.files;
    if (fileIndex < 0 || fileIndex >= files.length) return false;

    final total = files[fileIndex].length;
    if (total == 0) return false;

    // Use task-level downloaded bytes as an approximation.
    final downloaded = task.downloaded ?? 0;

    // Ready when we have at least 500 KB or 5% of the file.
    const minBytes = 500 * 1024;
    final threshold = (total * 0.05).round();
    return downloaded >= minBytes || downloaded >= threshold;
  }

  @override
  Future<void> pause(String infoHash) async {
    final task = _tasks[infoHash];
    if (task == null) {
      throw StateError('No torrent found for info hash: $infoHash');
    }
    task.pause();
  }

  @override
  Future<void> resume(String infoHash) async {
    final task = _tasks[infoHash];
    if (task == null) {
      throw StateError('No torrent found for info hash: $infoHash');
    }
    task.resume();
  }

  @override
  Future<void> remove(String infoHash, {bool deleteFiles = false}) async {
    final task = _tasks.remove(infoHash);
    if (task != null) {
      try {
        await task.stop();
      } catch (_) {}
    }
    _models.remove(infoHash);
    final listener = _listeners.remove(infoHash);
    if (listener != null) unawaited(listener.dispose());

    final controller = _statusControllers.remove(infoHash);
    if (controller != null) unawaited(controller.close());
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Extract the hex info hash from a magnet URI.
  static String _extractInfoHash(String magnetUri) {
    final uri = Uri.parse(magnetUri);
    final xt = uri.queryParameters['xt'];
    if (xt != null && xt.startsWith('urn:btih:')) {
      return xt.substring('urn:btih:'.length).toLowerCase();
    }
    throw ArgumentError('Invalid magnet URI: missing xt=urn:btih: parameter');
  }

  /// Download torrent metadata from DHT + peers via BEP 9 (metadata exchange).
  ///
  /// Returns a parsed [Torrent] model.  Times out after 2 minutes.
  Future<Torrent> _downloadMetadata(String infoHash) async {
    final completer = Completer<Torrent>();
    final downloader = dt.MetadataDownloader(infoHash);
    final listener = downloader.createListener();

    listener
      ..on<dt.MetaDataDownloadComplete>((event) {
        try {
          final decoded = decode(Uint8List.fromList(event.data));
          final torrentMap = <String, dynamic>{'info': decoded};
          final model = TorrentParser.parse(torrentMap);
          completer.complete(model);
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(
              TorrentEngineException(
                'Failed to parse torrent metadata: $e',
                cause: e,
              ),
            );
          }
        }
      })
      ..on<dt.MetaDataDownloadFailed>((event) {
        if (!completer.isCompleted) {
          completer.completeError(
            TorrentEngineException(
              'Metadata download failed: ${event.error}',
            ),
          );
        }
      });

    await downloader.startDownload();

    try {
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw TimeoutException(
            'Metadata download timed out — no peers found for this torrent',
            const Duration(minutes: 2),
          );
        },
      );
    } finally {
      unawaited(listener.dispose());
      try {
        await downloader.stop();
      } catch (_) {}
    }
  }

  /// Poll all active tasks and emit status updates.
  void _pollStatuses() {
    if (_disposed) return;
    for (final infoHash in _tasks.keys.toList()) {
      _emitStatus(infoHash);
    }
  }

  /// Build and emit a [TorrentStatus] for the given info hash.
  void _emitStatus(String infoHash) {
    // ignore: close_sinks
    final controller = _statusControllers[infoHash];
    if (controller == null || controller.isClosed) return;

    final task = _tasks[infoHash];
    if (task == null) return;

    final downloaded = task.downloaded ?? 0;
    final model = _models[infoHash];
    final total = model?.length ?? 0;

    TorrentState state;
    final progress = task.progress;
    if (total == 0) {
      state = TorrentState.metadata;
    } else if (progress >= 1.0) {
      state = TorrentState.complete;
    } else {
      state = TorrentState.downloading;
    }

    // currentDownloadSpeed is in bytes/ms — convert to bytes/s.
    final dlSpeed = (task.currentDownloadSpeed * 1000).round();
    final ulSpeed = (task.uploadSpeed * 1000).round();

    controller.add(
      TorrentStatus(
        infoHash: infoHash,
        state: state,
        progress: progress,
        downloadSpeed: dlSpeed,
        uploadSpeed: ulSpeed,
        totalSize: total,
        downloadedSize: downloaded,
        numPeers: task.connectedPeersNumber,
      ),
    );
  }
}
