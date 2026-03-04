# Changelog

All notable changes to CrispyTivi will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-alpha] - 2026-03-04

Initial public alpha release.

### Core Architecture

- Rust core engine (`crispy-core`) with SQLite WAL-mode database
- FFI bridge (`crispy-ffi`) for native platforms via flutter_rust_bridge
- WebSocket server (`crispy-server`) for web platform via Axum
- 168 FFI bridge functions, 20 database tables, 5+ indexes
- Thread-safe service layer (`OnceLock<Mutex<CrispyService>>`)
- JSON serialization bridge for complex types across FFI boundary

### Streaming and Playback

- Live TV with M3U and Xtream Codes playlist support
- Electronic Program Guide (EPG) with multi-day zoomable timeline
- VOD browsing with categories, search, sort, and favorites
- Series browser with season/episode navigation and continue watching
- Video player with OSD, sleep timer, aspect ratio, audio/subtitle
  track selection, playback speed, and picture-in-picture
- Channel zapping with group filter tabs
- Multiview for simultaneous streams
- DVR recording support

### Discovery and Organization

- Cross-content search across live, VOD, and series
- Voice search via speech-to-text
- TMDB-powered content recommendations
- Per-profile favorites with category filtering

### Connectivity

- Chromecast discovery and streaming via Google Cast
- AirPlay support for Apple devices
- Google Drive cloud sync
- WebDAV and SSH remote backup and restore
- External player launch (VLC, MX Player, etc.)

### User Management

- Multi-profile support with per-profile favorites, watch history,
  and settings
- Parental controls with content restriction and PIN protection
- Push notifications for new content

### Platform Support

- Windows, macOS, Linux (native FFI)
- Android phones, tablets, and Android TV / Fire TV (single APK)
- iOS
- Web (Rust companion server + Flutter WebSocket client)

### UI and Design

- Dark glassmorphism theme with Material 3 dynamic color
- Full keyboard, gamepad, and remote control navigation
- Responsive layouts for phone, tablet, desktop, and TV form factors

### Testing and Quality

- 799 Rust tests covering core algorithms, parsers, and services
- 1800+ Flutter tests (unit, widget, feature, golden)
- CI pipeline with 11 jobs, formatting checks, clippy enforcement,
  and test count thresholds
- Zero analyzer warnings

### Planned (Not Yet Implemented)

- Media server integration (Jellyfin, Emby, Plex)
- Video upscaling and super resolution (spec written, architecture
  designed for cross-platform GPU detection with 5-tier fallback)
