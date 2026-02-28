# Architecture — TorrentMusic

## High-Level Flow

```
User searches "Bohemian Rhapsody"
        │
        ▼
┌──────────────┐     ┌─────────────────┐
│  Search      │────▶│ Torrent Indexers │
│  Service     │◀────│ (Jackett/direct) │
└──────┬───────┘     └─────────────────┘
       │ results (magnet links + metadata)
       ▼
┌──────────────┐     ┌─────────────────┐
│  Metadata    │────▶│ MusicBrainz API │
│  Service     │◀────│ (enrich results)│
└──────┬───────┘     └─────────────────┘
       │ enriched track info
       ▼
┌──────────────┐
│  UI: Search  │  User selects a track
│  Results     │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌─────────────────┐
│  Torrent     │────▶│ libtorrent      │
│  Engine      │◀────│ (C++ via FFI)   │
└──────┬───────┘     └─────────────────┘
       │ progressive download (sequential pieces)
       ▼
┌──────────────┐     ┌─────────────────┐
│  Audio       │────▶│ just_audio      │
│  Player      │◀────│ (local file)    │
└──────────────┘     └─────────────────┘
```

## Streaming Strategy

1. User selects a track from search results
2. Torrent Engine resolves the magnet link and connects to peers
3. Engine prioritizes pieces sequentially from file start
4. Once enough buffer is downloaded (~500KB), Audio Player begins playback
5. Engine continues downloading remaining pieces in order
6. Player reads from the partially downloaded file

### Piece Prioritization

- Pieces 0..N (first 5% of file): HIGHEST priority
- Pieces N+1..M (next 10%): HIGH priority
- Remaining pieces: NORMAL priority
- This ensures playback starts fast while the rest downloads

## Data Models

### Track
```dart
class Track {
  String id;
  String title;
  String artist;
  String album;
  String? artworkUrl;
  Duration? duration;
  String magnetUri;
  int fileIndex;        // index within torrent if multi-file
  String? filePath;     // local path once (partially) downloaded
  int? bitrate;
  String? format;       // mp3, flac, ogg, etc.
}
```

### Playlist
```dart
class Playlist {
  String id;
  String name;
  DateTime createdAt;
  List<Track> tracks;
}
```

### TorrentStatus
```dart
class TorrentStatus {
  String infoHash;
  double progress;      // 0.0 - 1.0
  int downloadRate;     // bytes/s
  int numPeers;
  TorrentState state;   // downloading, seeding, paused, error
  List<bool> pieces;    // bitfield
}
```

## Module Dependencies

```
ui/ ──▶ player/ ──▶ core/
 │                    ▲
 ├──▶ search/ ────────┘
 │
 └──▶ library/
```

- `ui/` depends on all modules (consumes services)
- `player/` depends on `core/` (needs file access from torrent engine)
- `search/` depends on `core/` (to initiate downloads from results)
- `library/` is independent (pure persistence)
- `core/` is independent (pure torrent engine)
