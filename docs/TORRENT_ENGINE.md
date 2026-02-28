# Torrent Engine Spec

## Overview

The torrent engine provides magnet link resolution, BitTorrent downloading with
sequential piece prioritization, and status monitoring — everything needed to
stream audio from torrents before the full file is downloaded.

## Chosen Approach (PoC)

**aria2c process wrapper via JSON-RPC.**

libtorrent FFI bindings are complex to set up cross-platform, so the MVP wraps
[aria2](https://aria2.github.io/) — a mature, cross-platform download utility
with built-in BitTorrent support and a JSON-RPC control interface.

### Why aria2c?

- Supports magnet URIs and `.torrent` files out of the box
- Has `bt-prioritize-piece=head` for sequential/streaming downloads
- JSON-RPC API gives full control (add, pause, resume, remove, status)
- Handles DHT, peer exchange, LSD automatically
- Available on macOS (`brew install aria2`), Linux (`apt install aria2`),
  and Windows (binary download)

### Trade-offs

| Pros | Cons |
|------|------|
| Fast to implement | Requires `aria2c` binary on the system |
| Battle-tested BitTorrent client | Extra process to manage |
| Full-featured (DHT, PEX, LSD) | Not embeddable on iOS/Android |
| Sequential download support | Slightly higher latency than in-process |

### Future iterations

- Replace with libtorrent FFI for mobile platforms
- Or use a pure Dart BitTorrent library once one matures
- Bundle aria2c binary for desktop releases

## Architecture

```
┌──────────────────────────────────────────┐
│            TorrentEngine (abstract)       │
│  addMagnet · listFiles · startStreaming   │
│  watchStatus · pause · resume · remove   │
└──────────────┬───────────────────────────┘
               │ implements
┌──────────────▼───────────────────────────┐
│            Aria2Engine                    │
│  Spawns aria2c subprocess                │
│  Communicates via JSON-RPC on localhost   │
│  Polls status every 1 second             │
│  Handles magnet → metadata GID transition│
└──────────────────────────────────────────┘
```

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

## Key Behaviors

- On `startStreaming()`: selects the target file and sets `bt-prioritize-piece=head=10M`
- Buffer threshold for playback: 500 KB or first 5% of file (whichever is smaller)
- Magnet links go through a metadata phase (GID transition) — the engine
  resolves this transparently via `followedBy` in aria2's status response
- Status polling at 1-second intervals emits `TorrentStatus` to watchers
- `seed-time=0`: stops seeding immediately after download completes (configurable later)

## aria2c Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `enable-rpc` | true | JSON-RPC control interface |
| `seed-time` | 0 | Don't seed after download (PoC) |
| `bt-prioritize-piece` | head=10M | Sequential streaming |
| `enable-dht` | true | Distributed hash table |
| `enable-peer-exchange` | true | Find more peers |
| `bt-enable-lpd` | true | Local peer discovery |
| `follow-torrent` | mem | Process .torrent in memory |

## Models

- **TorrentState**: `metadata | downloading | seeding | paused | error | complete`
- **TorrentFile**: `{index, path, size}`
- **TorrentStatus**: `{infoHash, state, progress, downloadSpeed, uploadSpeed, totalSize, downloadedSize, numPeers, errorMessage}`

## Testing

Unit tests use a mock HTTP client to simulate aria2c RPC responses — no real
aria2c required. Integration tests (skipped when aria2c is not installed)
verify the full subprocess lifecycle.

Run tests:
```bash
flutter test test/core/torrent_engine_test.dart
```
