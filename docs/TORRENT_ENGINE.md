# Torrent Engine Spec

## Overview

The torrent engine provides magnet link resolution, BitTorrent downloading with
sequential piece prioritization, and status monitoring — everything needed to
stream audio from torrents before the full file is downloaded.

## Platform Strategy

The app ships **two** `TorrentEngine` implementations. A platform-aware factory
(`createPlatformEngine()` in `core_providers.dart`) picks the right one at
runtime.

| Platform | Engine | How it works |
|----------|--------|-------------|
| Android / iOS | `DartTorrentEngine` | Pure Dart via `dtorrent_task_v2` — no external binary |
| macOS / Linux / Windows | `Aria2Engine` | Wraps the `aria2c` subprocess via JSON-RPC |

### Why two engines?

`aria2c` is a mature desktop download utility but **cannot run on mobile**
(Android / iOS have no user-accessible shell or package manager). The original
PoC only shipped `Aria2Engine`, which meant the entire download pipeline was
broken on mobile — the app could search but never download or play anything.

`DartTorrentEngine` fixes this by using [dtorrent_task_v2], a pure-Dart
BitTorrent library that runs everywhere the Dart VM runs. It supports sequential
downloading optimised for audio/video streaming, DHT, tracker scraping, and
peer exchange — no native code or external process needed.

[dtorrent_task_v2]: https://pub.dev/packages/dtorrent_task_v2

## Interface

```dart
abstract class TorrentEngine {
  Future<void> init({String? cachePath, int? maxConnections});
  Future<String> addMagnet(String magnetUri);
  Future<List<TorrentFile>> listFiles(String infoHash);
  Future<String> startStreaming(String infoHash, int fileIndex);
  Stream<TorrentStatus> watchStatus(String infoHash);
  Future<bool> isReadyForPlayback(String infoHash, int fileIndex);
  Future<void> pause(String infoHash);
  Future<void> resume(String infoHash);
  Future<void> remove(String infoHash, {bool deleteFiles = false});
  Future<void> dispose();
}
```

A `TorrentEngineException` is thrown for fatal, user-actionable errors (e.g.
aria2c not installed). The `PlaybackOrchestrator` catches these and surfaces
the `message` directly in the UI.

## DartTorrentEngine (Android / iOS / all platforms)

### How it works

1. **Metadata resolution** — `MetadataDownloader.fromMagnet()` contacts the DHT
   and peers to obtain the torrent's info dictionary (file list, piece hashes).
   Times out after 2 minutes.
2. **Task creation** — `TorrentTask.newTask()` is created with
   `SequentialConfig.forAudioStreaming()` for sequential piece selection.
3. **File selection** — `startStreaming()` sets the target file to high priority
   and all others to `dontDownload`, so bandwidth is concentrated on the
   requested audio file.
4. **Status polling** — A 1-second timer emits `TorrentStatus` snapshots to
   watchers, matching the cadence of `Aria2Engine`.
5. **Playback readiness** — Same threshold as `Aria2Engine`: 500 KB or 5% of
   the file, whichever is smaller.

### Dependencies

- `dtorrent_task_v2: ^0.4.1` (pure Dart, no native code)

### Capabilities (via dtorrent_task_v2)

| Feature | Supported |
|---------|-----------|
| Magnet URI resolution | Yes |
| Sequential / streaming download | Yes (adaptive buffering) |
| DHT | Yes |
| Peer exchange | Yes |
| Web seeding (BEP 19) | Yes |
| Selected file download (BEP 53) | Yes |
| BitTorrent v2 (BEP 52) | Yes |
| Proxy (SOCKS5) | Yes |
| Fast resume | Yes |

## Aria2Engine (Desktop)

### How it works

Spawns `aria2c` as a child process and communicates via its JSON-RPC interface
on `localhost:<port>`.

### Requirements

`aria2c` must be installed on the system:
- macOS: `brew install aria2`
- Linux: `apt install aria2`
- Windows: download from https://aria2.github.io/

If `aria2c` is not found, `init()` throws a `TorrentEngineException` with
installation instructions — the UI shows this to the user.

### aria2c Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `enable-rpc` | true | JSON-RPC control interface |
| `seed-time` | 0 | Don't seed after download (PoC) |
| `bt-prioritize-piece` | head=10M | Sequential streaming |
| `enable-dht` | true | Distributed hash table |
| `enable-peer-exchange` | true | Find more peers |
| `bt-enable-lpd` | true | Local peer discovery |
| `follow-torrent` | mem | Process .torrent in memory |

## Architecture

```
┌──────────────────────────────────────────┐
│            TorrentEngine (abstract)       │
│  addMagnet · listFiles · startStreaming   │
│  watchStatus · pause · resume · remove   │
└──────────────┬───────────────────────────┘
               │ implements
       ┌───────┴───────┐
       │               │
┌──────▼──────┐ ┌──────▼──────────┐
│ Aria2Engine │ │DartTorrentEngine │
│ (desktop)   │ │ (all platforms)  │
│ aria2c RPC  │ │ dtorrent_task_v2 │
└─────────────┘ └─────────────────┘

                    selected by
              createPlatformEngine()
```

## Key Behaviors

- Buffer threshold for playback: 500 KB or first 5% of file (whichever is smaller)
- Status polling at 1-second intervals emits `TorrentStatus` to watchers
- `DartTorrentEngine` metadata resolution has a 2-minute timeout
- `Aria2Engine` RPC readiness has a 6-second timeout (30 × 200ms)
- `seed-time=0` on Aria2Engine: stops seeding immediately after download

## Models

- **TorrentState**: `metadata | downloading | seeding | paused | error | complete`
- **TorrentFile**: `{index, path, size}`
- **TorrentStatus**: `{infoHash, state, progress, downloadSpeed, uploadSpeed, totalSize, downloadedSize, numPeers, errorMessage}`
- **TorrentEngineException**: `{message, cause}` — fatal, user-actionable errors

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| aria2c not installed (desktop) | `TorrentEngineException` with install instructions |
| aria2c RPC timeout | `TorrentEngineException` suggesting port conflict |
| Metadata download timeout (DartTorrentEngine) | `TimeoutException` after 2 min |
| `addMagnet` / `startStreaming` failure | Caught by `PlaybackOrchestrator`, emitted as `PlaybackPreparationState.error` with a human-readable message |
| No peers available | Timeout → UI message suggesting trying a result with more seeds |

## Testing

Unit tests use a mock `TorrentEngine` — no real aria2c or network required.
Integration tests (skipped when aria2c is not installed) verify `Aria2Engine`.

```bash
# Unit tests
flutter test test/core/torrent_engine_test.dart

# Full test suite
flutter test
```

## Future Work

- Bundle aria2c binary in desktop release builds for zero-config desktop UX
- Evaluate replacing Aria2Engine with DartTorrentEngine on all platforms once
  the library matures further
- Add seeding support (configurable seed ratio / time)
- Add per-file download progress tracking in `DartTorrentEngine`
