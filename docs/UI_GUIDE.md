# UI Guide — TorrentMusic

## Design Principles
- Dark theme by default (music app vibes)
- Clean, minimal — content first
- Responsive: works on phone, tablet, desktop
- Smooth animations on transitions and player

## Screens (MVP)

### 1. Search Screen (Home)
- Search bar at top
- Results as list: track name, artist, seeds/size
- Tap to play, long press for options (add to playlist, etc.)

### 2. Now Playing
- Full-screen player
- Album art (large)
- Track info (title, artist, album)
- Progress bar with seek
- Controls: prev, play/pause, next, shuffle, repeat
- Download progress indicator (torrent)
- Mini-player bar when collapsed

### 3. Queue
- Current queue / up next
- Drag to reorder
- Swipe to remove

### 4. Library (Phase 2)
- Tabs: Playlists, Favorites, Recent, Downloads
- Grid/list toggle for albums

### 5. Settings
- Cache size limit
- Default audio quality preference
- Tracker/indexer configuration
- Theme (dark/light/system)
- Last.fm scrobbling toggle

## Navigation
- Bottom nav: Search | Library | Settings
- Mini-player persistent above bottom nav
- Now Playing: slide up from mini-player

## Theme
- Primary: Deep purple / electric blue
- Background: #0D0D0D
- Surface: #1A1A1A
- Accent: configurable
- Font: System default (or Inter/Poppins)
