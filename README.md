# CrispyTivi

> **Alpha Software** — This project is under active development.
> Expect breaking changes, incomplete features, and rough edges.
> Your feedback and contributions help shape it.

A cross-platform IPTV and media streaming app built with Flutter and
Rust. Supports M3U, Xtream Codes, EPG, VOD, and Series, with planned
Jellyfin, Emby, and Plex integrations. Designed for living-room use
with full keyboard, gamepad, and remote control navigation.

---

## Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/moabualruz/crispy-tivi/main/docs/screenshots/desktop-home.png" alt="Home — Desktop" width="800" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/moabualruz/crispy-tivi/main/docs/screenshots/desktop-movies.png" alt="Movies — Desktop" width="395" />
  <img src="https://raw.githubusercontent.com/moabualruz/crispy-tivi/main/docs/screenshots/desktop-guide.png" alt="EPG Guide — Desktop" width="395" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/moabualruz/crispy-tivi/main/docs/screenshots/tv-home.png" alt="Home — TV" width="800" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/moabualruz/crispy-tivi/main/docs/screenshots/mobile-home.png" alt="Home — Mobile" width="200" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/moabualruz/crispy-tivi/main/docs/screenshots/mobile-movies.png" alt="Movies — Mobile" width="200" />
</p>

---

## About This Project

CrispyTivi is a **passion project** — built for the love of learning,
tinkering, and solving real problems around media streaming. It started
as a personal challenge to build a cross-platform IPTV app with a Rust
core and a Flutter UI, and it grew into something worth sharing.

This is **not** a commercial product. It's open source so that others
can learn from the architecture, contribute improvements, and help test
across the many platforms it targets. Whether you're into Flutter, Rust,
media streaming, TV app development, or just want a solid IPTV player,
you're welcome here.

---

## Features

### Streaming and Playback

- **Live TV** — M3U and Xtream Codes playlists, channel groups,
  favorites, EPG overlay
- **EPG Timeline** — Multi-day electronic program guide with
  zoomable grid
- **VOD Browser** — Categories, search, sort, favorites for
  movies and series
- **Series Browser** — Season and episode navigation, continue
  watching, recently added
- **Video Player** — On-screen display, sleep timer, aspect ratio,
  audio and subtitle tracks, playback speed, picture-in-picture
- **Channel Zapping** — Quick switch with group filter tabs
- **Multiview** — Watch multiple streams simultaneously
- **DVR** — Recording support

### Discovery and Organization

- **Search** — Cross-content search across live, VOD, and series
- **Voice Search** — Speech-to-text content search
- **Recommendations** — TMDB-powered content suggestions
- **Favorites** — Per-profile favorites with category filtering

### Connectivity

- **Chromecast** — Cast discovery and streaming via Google Cast
- **AirPlay** — Apple device streaming support
- **Cloud Sync** — Google Drive backup and sync
- **Backup and Restore** — WebDAV and SSH remote backup
- **External Players** — Launch in VLC, MX Player, and more

### User Management

- **Multi-Profile** — Per-profile favorites, watch history, settings
- **Parental Controls** — Content restriction and PIN protection
- **Notifications** — Push notifications for new content

### Planned

- **Media Server Integration** — Jellyfin, Emby, and Plex support
- **Video Upscaling** — GPU-accelerated super resolution with
  cross-platform fallback chain

---

## Platforms

| Platform   | Status    |
| ---------- | --------- |
| Windows    | Supported |
| macOS      | Supported |
| Linux      | Supported |
| Android    | Supported |
| Android TV | Supported |
| iOS        | Supported |
| Web        | Supported |

Android builds produce a single universal APK covering phones,
tablets, and Android TV / Fire TV (via Leanback launcher).

> **iOS note:** Pre-built iOS binaries are not included in releases
> because Apple requires code signing. To run on your iOS device,
> clone the repo, open `app/flutter/ios/Runner.xcworkspace` in Xcode, set your
> own signing team under Signing & Capabilities, and build to your
> device. A free Apple Developer account works for personal testing
> (apps expire after 7 days). See [Getting Started](#getting-started)
> for full setup instructions.
>
> We need help testing on platforms we don't have daily access to —
> especially macOS, iOS, Linux, and various Android TV devices.
> If you can run a build and report issues, that's a huge help.

---

## Architecture

**Rust core + Flutter shell.** All business logic and data persistence
lives in Rust. Flutter is a pure UI client.

- **Native** (Windows, macOS, Linux, Android, iOS) — Rust is embedded
  via FFI. Single executable, no server needed.
- **Web** — Rust runs as a companion server. Flutter web connects via
  WebSocket. No browser storage.

```text
rust/
  crates/          # App-owned Rust crates used only by CrispyTivi
    crispy-core/   # Business logic + persistence
    crispy-ffi/    # Native bridge for Flutter
    crispy-server/ # Web/WebSocket companion server
  shared/          # Exported first-party Rust crates (separate repos)

app/flutter/lib/               # Flutter application code
  core/            # Shared app infrastructure
  features/        # Feature-first UI modules
  l10n/            # Generated localization bindings

app/flutter/test/              # Dart unit/widget tests
app/flutter/integration_test/  # Device and end-to-end integration tests
scripts/           # Build, release, and validation scripts
docs/              # Repository documentation and screenshots
```

## Repository Layout

The repository is intentionally split by ownership and release boundary:

- `app/flutter/lib/`, `app/flutter/test/`, `app/flutter/integration_test/`, and platform folders (`app/flutter/android/`, `app/flutter/ios/`, `app/flutter/linux/`, `app/flutter/macos/`, `app/flutter/windows/`, `app/flutter/web/`) are the Flutter app.
- `rust/crates/` contains app-internal Rust crates that ship with CrispyTivi.
- `rust/shared/` contains exported first-party Rust crates tracked as submodules because they are published and versioned independently.
- `scripts/` contains platform, build, release, and validation automation.
- `docs/` contains durable repository documentation and screenshot assets.

Local tool state and generated output do not belong in the repository root and are ignored.

## Tech Stack

| Concern          | Technology                     |
| ---------------- | ------------------------------ |
| UI Framework     | Flutter 3.7+ / Dart ^3.7.0     |
| Core Engine      | Rust (crispy-core)             |
| FFI Bridge       | flutter_rust_bridge            |
| State Management | Riverpod 3.x + code generation |
| Video Engine     | media_kit (libmpv / FFmpeg)    |
| Database         | rusqlite (SQLite WAL mode)     |
| Network          | Dio + Retrofit                 |
| Routing          | GoRouter                       |
| Web Server       | Axum + tokio-tungstenite       |
| Cloud Storage    | WebDAV, SSH, Google Drive      |
| Casting          | mDNS + Protobuf (Google Cast)  |
| Voice            | speech_to_text                 |
| UI               | Material 3, dark glassmorphism |

---

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) 3.7+
- [Rust](https://rustup.rs/) (stable toolchain)
- Platform-specific build tools (Xcode, Android SDK, Visual Studio, etc.)

### Setup

```bash
# Clone the repository
git clone https://github.com/nicericelover/CrispyTivi.git
cd CrispyTivi

# Build Rust core
cd rust && cargo build --release && cd ..

# Flutter setup
cd app/flutter && flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running

```bash
# Native (Rust embedded via FFI)
cd app/flutter && flutter run -d windows
cd app/flutter && flutter run -d macos
cd app/flutter && flutter run -d linux
cd app/flutter && flutter run -d android

# Web (start the Rust server first, then Flutter)
cargo run -p crispy-server --manifest-path rust/Cargo.toml
cd app/flutter && flutter run -d chrome --web-port 3000

# Web (custom port and local network access)
cargo run -p crispy-server --manifest-path rust/Cargo.toml -- --port 3030
cd app/flutter && flutter run -d chrome --web-hostname 0.0.0.0 --web-port 3000 --dart-define=CRISPY_PORT=3030
```

## Building

```bash
cd app/flutter && flutter build windows          # Windows EXE
cd app/flutter && flutter build apk --release    # Android APK (universal)
cd app/flutter && flutter build web --release    # Web app
cd app/flutter && flutter build macos            # macOS app
cd app/flutter && flutter build linux --release  # Linux
```

### Serving the Web Build

```bash
# Development (default server port 8080)
cd rust && cargo run -p crispy-server --release &
cd app/flutter && flutter run -d chrome --web-port 3000

# Production preview
cd rust && cargo run -p crispy-server --release &
cd app/flutter && flutter build web --release
npx serve app/flutter/build/web -p 3000
```

## Testing

| Layer            | Command                                    |
| ---------------- | ------------------------------------------ |
| Rust core        | `cd rust && cargo test`                    |
| Unit / Widget    | `cd app/flutter && flutter test` |
| Golden (visual)  | `cd app/flutter && flutter test test/golden/` |
| Integration      | `cd app/flutter && flutter test integration_test/` |
| E2E (Playwright) | `cd testing/playwright && npx playwright test` |

The project has **799 Rust tests** and **1800+ Flutter tests** with
CI enforcing zero analyzer warnings and formatting checks.

---

## Support the Project

CrispyTivi is free and open source. If you find it useful or want
to support its continued development, here are ways to help:

- **Sponsor** — [Buy Me a Coffee](https://buymeacoffee.com/mohdkhairruzz)
- **Contribute** — Open a pull request (see [CONTRIBUTING.md](CONTRIBUTING.md))
- **Test** — Run builds on your devices and report issues
- **Report bugs** — [Open an issue](../../issues) with reproduction steps
- **Spread the word** — Star the repo, share it with friends

Every contribution matters, no matter how small.

---

## Join the Team

Looking for people with expertise in any of the following to help
maintain and improve the project:

- **Flutter / Dart** — UI, state management, platform channels
- **Rust** — Core engine, FFI, performance
- **Mobile app development** — Android, iOS, platform-specific issues
- **TV app development** — Android TV, Fire TV, focus navigation, D-pad
- **Media streaming** — IPTV protocols, video codecs, player engines
- **DevOps / CI** — Build pipelines, cross-platform packaging

If you're interested, reach out:

- **Twitter / X:** [@TheRiceFather](https://x.com/TheRiceFather)
- **GitHub:** [Open an issue](https://github.com/moabualruz/crispy-tivi/issues)
  or start a discussion

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines,
commit conventions, and pull request requirements.

## License

**CC BY-NC-SA 4.0** — Creative Commons Attribution-NonCommercial-ShareAlike
4.0 International.

This is a source-available project. You are free to read, learn from,
and contribute to the code. Commercial use, redistribution, and
republication require explicit permission from the author.

See [LICENSE.md](LICENSE.md) and [NOTICE.md](NOTICE.md) for full details.
