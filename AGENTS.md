# AGENTS.md — TorrentMusic

## Project Overview

TorrentMusic is an open-source, cross-platform music streaming app built with Flutter.
It streams music directly from torrents using progressive downloading.

## Architecture

```
lib/
├── core/           # Torrent engine, FFI bindings to libtorrent
├── player/         # Audio playback service, queue management
├── search/         # Torrent search, metadata (MusicBrainz), lyrics (LRCLIB)
├── library/        # Local DB, playlists, favorites, history
├── ui/             # Screens, widgets, themes, navigation
│   ├── screens/
│   ├── widgets/
│   └── theme/
└── app.dart        # Entry point

native/             # C++ libtorrent wrapper for FFI
test/               # Unit + integration tests
docs/               # Architecture docs, specs per module
```

## Conventions

### Code
- **Language:** Dart (Flutter 3.x)
- **State management:** Riverpod
- **Local DB:** Drift (SQLite)
- **Formatting:** `dart format` — must pass before PR
- **Analysis:** `dart analyze` — zero warnings before PR
- **Tests:** Required for all business logic (core, player, search, library)

### Git
- **Branching:** `feature/<name>`, `fix/<name>`, `refactor/<name>`
- **Commits:** Conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`)
- **PRs:** One PR per feature/fix. Clear description of what and why.
- **Reviews:** All PRs reviewed before merge.

### Agent Rules
- Stay in your domain — don't modify files outside your assigned module without coordination.
- Run `dart format .` and `dart analyze` before opening a PR.
- Include tests for new logic.
- If you need something from another module, define an interface and document the dependency.
- If blocked, document the blocker in the PR description.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | Flutter (iOS, Android, macOS, Windows, Linux) |
| State Mgmt | Riverpod |
| Torrent Engine | libtorrent via dart:ffi |
| Audio Player | just_audio |
| Database | Drift (SQLite) |
| Metadata | MusicBrainz API |
| Lyrics | LRCLIB |
| Scrobbling | Last.fm API (optional) |

## Module Ownership

| Module | Description |
|--------|-------------|
| `core/` | Torrent engine — FFI bindings, download management, piece prioritization, cache |
| `player/` | Audio playback — streaming from partial files, queue, repeat/shuffle, system media controls |
| `search/` | Search indexers, parse torrent contents, fetch metadata & artwork |
| `library/` | SQLite persistence — playlists, favorites, history, cache management |
| `ui/` | All screens and widgets — search, player, library, settings |
