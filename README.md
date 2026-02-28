# 🎵 TorrentMusic

Open-source, cross-platform music streaming from torrents.

**Like Stremio, but for music.** Search for any song, album, or artist — stream it instantly from torrent sources without waiting for full downloads.

## Features (planned)

- 🔍 Search music across torrent indexers
- ▶️ Stream while downloading (progressive torrent)
- 📚 Personal library with playlists & favorites
- 🎨 Album art & metadata via MusicBrainz
- 📝 Synced lyrics
- 📊 Last.fm scrobbling
- 🌙 Beautiful dark UI

## Platforms

- Android
- iOS
- macOS
- Windows
- Linux

## Tech Stack

- **Flutter** — Cross-platform UI
- **libtorrent** — Torrent engine (via FFI)
- **just_audio** — Audio playback
- **Riverpod** — State management
- **Drift** — Local database (SQLite)
- **MusicBrainz** — Metadata & cover art

## Development

```bash
flutter pub get
flutter run
```

## Status

🚧 Early development — MVP in progress.

## License

MIT
