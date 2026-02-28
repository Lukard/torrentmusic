# Search & Metadata Spec

## Search

### Sources
- Public torrent indexers via Jackett API (if available)
- Direct scraping of public trackers (fallback)
- User-configurable tracker list in settings

### Interface

```dart
abstract class SearchService {
  /// Search for music torrents
  Future<List<SearchResult>> search(String query, {SearchType? type});

  /// Get detailed info about a specific torrent
  Future<TorrentDetail> getDetail(String magnetUri);
}

enum SearchType { track, album, artist }

class SearchResult {
  String title;
  String magnetUri;
  int seeds;
  int leeches;
  int sizeBytes;
  String? category;    // music, lossless, etc.
  String source;       // which indexer
}
```

## Metadata Enrichment

### MusicBrainz
- Match search results to MusicBrainz recordings
- Fetch: artist, album, track number, release year, genre
- Cover art via Cover Art Archive (coverartarchive.org)

### LRCLIB (Phase 3)
- Fetch synced lyrics by artist + title + duration
- Fallback to unsynced lyrics

### Interface

```dart
abstract class MetadataService {
  Future<TrackMetadata?> enrich(String title, String artist);
  Future<String?> getCoverArt(String musicBrainzReleaseId);
  Future<Lyrics?> getLyrics(String title, String artist, Duration duration);
}
```
