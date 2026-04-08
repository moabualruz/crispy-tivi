# Project Index: CrispyTivi

Generated: 2026-04-06 (updated)

## Project Summary

**CrispyTivi** — Cross-platform IPTV & media streaming application.
Flutter UI (Dart) + Rust backend (crispy-core via FFI).
State: Riverpod. Video: media_kit. DB: SQLite (rusqlite in Rust, sqflite in Dart).
Design: Dark glassmorphism ("Cinematic Utility").
Version: 0.1.0-alpha

## Project Structure

```
crispy-tivi/
├── lib/                        # Flutter/Dart source (786 files)
│   ├── main.dart               # App entry point
│   ├── config/                 # AppConfig, SettingsNotifier (8 files)
│   ├── core/                   # Shared infrastructure (13 modules)
│   │   ├── data/               # CacheService, backends (FFI/WS/Memory) (62 files)
│   │   ├── navigation/         # GoRouter, app shell, side nav (11 files)
│   │   ├── network/            # Dio HTTP service (6 files)
│   │   ├── theme/              # Design tokens: spacing, radius, animation, colors (11 files)
│   │   ├── widgets/            # Reusable UI components (75 files)
│   │   ├── utils/              # Platform, form factor, formatters (34 files)
│   │   ├── domain/             # Base entities (MediaItem, PlaylistSource) (7 files)
│   │   ├── providers/          # Global Riverpod providers (3 files)
│   │   ├── failures/           # Error hierarchy (1 file)
│   │   ├── exceptions/         # Custom exceptions (1 file)
│   │   ├── extensions/         # Dart extensions (1 file)
│   │   ├── lint/               # Custom lint rules (3 files)
│   │   └── testing/            # TestKeys class (1 file)
│   ├── features/               # 20 feature modules (Clean Architecture)
│   │   ├── player/             # Video playback, OSD, upscaling (140 files)
│   │   ├── settings/           # App preferences (57 files)
│   │   ├── vod/                # Video on Demand browser (50 files)
│   │   ├── iptv/               # Live TV sources, channel sync (49 files)
│   │   ├── dvr/                # Recording, transfer, storage (47 files)
│   │   ├── media_servers/      # Jellyfin, Emby, Plex (40 files)
│   │   ├── epg/                # Electronic Program Guide (22 files)
│   │   ├── profiles/           # User profiles, PIN, roles (21 files)
│   │   ├── search/             # Full-text search (19 files)
│   │   ├── multiview/          # 4-way split view (16 files)
│   │   ├── favorites/          # Watch lists, bookmarks (16 files)
│   │   ├── home/               # Dashboard, recommendations (11 files)
│   │   ├── cloud_sync/         # Google Drive sync (10 files)
│   │   ├── onboarding/         # First-time setup wizard (7 files)
│   │   ├── casting/            # Chromecast (6 files)
│   │   ├── airplay/            # AirPlay (4 files)
│   │   ├── recommendations/    # Content suggestions (4 files)
│   │   ├── voice_search/       # Voice command (4 files)
│   │   ├── parental/           # Content rating filter (2 files)
│   │   └── notifications/      # Toasts (2 files)
│   ├── l10n/                   # 9 languages (en, es, fr, de, pt, ru, zh, ar, tr)
│   └── src/rust/               # FFI bindings (auto-generated)
├── rust/                       # Rust backend (~82,665 LOC, 301 .rs files)
│   └── crates/                 # 12 crates
│       ├── crispy-core/        # Business logic, parsers, DB, crypto
│       ├── crispy-ffi/         # Flutter FFI bridge
│       ├── crispy-server/      # Axum WebSocket server
│       ├── crispy-m3u/         # M3U playlist parser
│       ├── crispy-xtream/      # Xtream Codes API client
│       ├── crispy-stalker/     # Stalker portal client
│       ├── crispy-xmltv/       # XMLTV/EPG parser
│       ├── crispy-iptv-types/  # Shared IPTV type definitions
│       ├── crispy-iptv-tools/  # IPTV utility functions
│       ├── crispy-media-probe/ # Media stream probing
│       ├── crispy-stream-checker/ # Stream availability checker
│       ├── crispy-catchup/     # Catch-up TV support
├── test/                       # Unit/widget tests (260 files)
│   ├── config/                 # Configuration tests
│   ├── core/                   # Core module tests (64 files)
│   ├── features/               # Feature tests (177 files)
│   ├── golden/                 # Visual regression (16 test files, 20 baselines)
│   ├── performance/            # Performance benchmarks (4 files)
│   └── regression/             # Bug fix validation (1 file)
├── integration_test/           # Native E2E tests (38 files)
│   ├── flows/                  # 16 end-to-end flows
│   ├── robots/                 # 6 page object models
│   ├── suites/                 # Test groupings
│   ├── helpers/                # Test app factory, fixtures
│   └── fixtures/               # Mock API data
├── e2e/playwright/             # Browser E2E tests (13 spec files)
├── .ai/                        # Design docs, requirements, planning (submodule)
├── assets/                     # Config, logos, GPU shaders
├── scripts/                    # Build & dev scripts
└── android/ios/linux/macos/web/windows/  # Platform shells
```

## Entry Points

- **App**: `lib/main.dart` — CrispyTiviApp, backend selection, window manager
- **Rust FFI**: `rust/crates/crispy-ffi/src/lib.rs` — 19 API modules exposed to Flutter
- **Web Server**: `rust/crates/crispy-server/src/main.rs` — Axum WS server (port 8080)
- **Router**: `lib/core/navigation/app_router.dart` — GoRouter configuration
- **Shell**: `lib/core/navigation/app_shell.dart` — Root layout with responsive nav
- **Tests**: `flutter test` | `flutter test integration_test/ -d windows` | `npx playwright test`

## Core Modules

### Rust: crispy-core (62,936 LOC)

#### Algorithms (24,500+ LOC, 7 subdirectories + 26 standalone modules)

| Module | LOC | Purpose |
|--------|-----|---------|
| `search.rs` | 1,364 | Full-text search with ranking |
| `sorting.rs` | 897 | Multi-criteria sorting |
| `categories.rs` | 822 | Channel/content categorization |
| `crypto.rs` | 775 | AES-256-GCM encryption, Argon2id PIN hashing |
| `merge_decisions.rs` | 686 | Conflict resolution for multi-source |
| `catchup.rs` | 603 | Catchup stream URL parsing |
| `stream_failover.rs` | 567 | Multi-stream failover with health scoring |
| `stream_alternatives.rs` | 553 | Failover logic for alternatives |
| `channel_dedup.rs` | 489 | Channel deduplication |
| `content_dedup.rs` | 425 | Content deduplication |
| `dedup.rs` | 409 | Generic deduplication |
| `search_grouping.rs` | 409 | Search result grouping |
| `timezone.rs` | 410 | Timezone conversion for EPG |
| `title_normalize.rs` | 371 | Title normalization |
| `quality_ranking.rs` | 346 | Stream quality ordering |
| `pin.rs` | 340 | PIN generation & validation |
| `epg_merge.rs` | 329 | EPG entry merging |
| `url_normalize.rs` | 311 | URL canonicalization |
| `normalize.rs` | 386 | EPG XML normalization |
| `epg_fuzzy.rs` | 275 | Fuzzy EPG matching |
| Subdirs: `cloud_sync/`, `dvr/`, `epg_matching/`, `recommendations/`, `vod_sorting/`, `watch_history/` | | |

#### Parsers (7,952 LOC, 8 formats)

| Parser | LOC | Purpose |
|--------|-----|---------|
| `stalker.rs` | 2,123 | Stalker MAC protocol |
| `vod.rs` | 1,539 | VOD JSON (series, seasons, movies) |
| `epg.rs` | 1,208 | XMLTV EPG |
| `m3u.rs` | 920 | M3U playlist |
| `xtream.rs` | 920 | Xtream API |
| `vtt.rs` | 610 | WebVTT subtitle sprites |
| `s3.rs` | 323 | S3 cloud storage |
| `bif.rs` | 298 | BIF trickplay images |

#### Services (25,116 LOC, 71 modules)

**Data Services**: channels, profiles, vod, epg, sources, smart_groups, history, dvr, bookmarks, categories, settings, watchlist, epg_mappings

**Sync Services**: stalker_sync (998 LOC), xtream_sync (576), m3u_sync (203), epg_sync (242)

**Platform Services**: cast_service, dlna_service (526), airplay_service, device_discovery (452), media_session (290), audio_output, display_manager (249)

**Security**: pin_security (527), secret_store (259), gdpr_service (374), content_filter (374), viewing_limits (402)

**Quality**: qoe_collector (558), stream_health (500), playback_recovery (296), playback_watchdog (270)

**Metadata**: logo_resolver (682), tmdb (999)

**Localization**: i18n_service (584), locale_format (554), theme_service (148)

**Resilience**: circuit_breaker, crash_recovery (251), reconnect_manager (253), diagnostics (556), retry_queue (286)

**Other**: deep_link_router (315), notification_service (415), import_service (560), update_checker (349), feature_flags (368), offline_outbox (272), watch_position_sync (483), network_monitor (237)

#### Database (1,141 LOC + 9 migrations)

- `mod.rs` — r2d2 connection pool, Database wrapper
- `migration_runner.rs` — Migration execution & version tracking
- `retry_queue.rs` — Persistent offline-first queue
- Migrations: 001 (initial schema) → 009 (vod extended fields)

### Dart: Core Layer

- **CacheService** (`core/data/cache_service.dart`) — In-memory cache backed by Rust DB (6 variants: channels, DVR, VOD, media, profiles, EPG)
- **CrispyBackend** (`core/data/`) — Abstract backend interface with 3 implementations:
  - FFI Backend (8 files) — Direct Rust calls (production)
  - Memory Backend (11 files) — In-memory mock (testing)
  - WebSocket Backend (8 files) — HTTP API (web/debug)
- **AppRouter** (`core/navigation/app_router.dart`) — GoRouter with adaptive transitions
- **AppShell** (`core/navigation/app_shell.dart`) — Root layout, responsive nav
- **Theme tokens** (`core/theme/`) — CrispyColors, CrispySpacing, CrispyRadius, CrispyAnimation, CrispyTypography, CrispyElevation
- **Widgets Library** (`core/widgets/`, 75 components) — glass_surface, focus_wrapper, screen_template, responsive_layout, tv_master_detail_layout, smart_image, etc.

### Dart: Feature Architecture

Each feature follows Clean Architecture: `domain/` (entities) → `data/` (services) → `application/` (orchestration, optional) → `presentation/` (providers + widgets)

| Feature | Files | Layers |
|---------|-------|--------|
| player | 140 | data(51) + domain(16) + presentation(73) |
| settings | 57 | data(6) + domain(2) + presentation(49) |
| vod | 50 | data(3) + domain(4) + presentation(43) |
| iptv | 49 | application(5) + data(7) + domain(6) + presentation(31) |
| dvr | 47 | data(13) + domain(11) + presentation(23) |
| media_servers | 40 | Plex(12) + Shared(20) + Emby(5) + Jellyfin(3) |
| epg | 22 | data + domain + presentation |
| profiles | 21 | data + domain + presentation |
| search | 19 | data + domain + presentation |
| multiview | 16 | data + domain + presentation |
| favorites | 16 | data + domain + presentation |
| home | 11 | domain + presentation |
| cloud_sync | 10 | data + domain + presentation |
| onboarding | 7 | presentation only |
| casting | 6 | data + presentation |
| recommendations | 4 | data + domain + presentation |
| voice_search | 4 | data + domain + presentation |
| airplay | 4 | data only |
| parental | 2 | data + domain |
| notifications | 2 | data + presentation |

## Key Types

| Type | Location | Purpose |
|------|----------|---------|
| `Channel` | Rust models | Live TV channel entity |
| `VodItem` | Rust models | Movie/series/episode entity |
| `EpgEntry` | Rust models | TV program guide entry |
| `UserProfile` | Rust models | User with PIN, role, permissions |
| `Source` | Rust models | IPTV source (M3U/Xtream/Stalker) |
| `CrispyService` | Rust services | Main orchestrator wrapping all services |
| `PlaybackState` | Dart domain | Player status, position, volume |
| `CacheService` | Dart core | Cross-platform data access layer |
| `CrispyBackend` | Dart core | Backend abstraction (FFI/WS/Memory) |

## Database Schema

Core: `channels`, `vod_content`, `epg_entries`, `sources`, `categories`
User: `profiles`, `favorites`, `watch_history`, `settings`
DVR: `recordings`, `storage_backends`, `transfer_tasks`
Support: `merge_decisions`, `retry_queue`, `epg_mappings`, `smart_groups`, `bookmarks`, `reminders`, `watchlist`, `saved_layouts`, `stream_health`

**Encryption**: Credentials stored with AES-256-GCM (migration 004)

## FFI Bridge (19 API Modules)

| Module | Purpose |
|--------|---------|
| algorithms | search, sort, rank streams |
| app_update | version checking |
| bookmarks | bookmark CRUD |
| buffer | buffer tier config |
| channels | channel CRUD, favorites |
| display | GPU detection, display info |
| dvr | recording management |
| epg | EPG sync (XMLTV, Xtream, Stalker) |
| lifecycle | initialize/shutdown |
| parsers | manual M3U/EPG/Xtream/Stalker parsing |
| profiles | profile management |
| settings | settings CRUD |
| smart_groups | dynamic group management |
| sources | source management |
| stream_health | stream URL validation |
| sync | multi-source sync orchestration |
| vod | VOD CRUD, series details |
| watchlist | watchlist CRUD |

## WebSocket Server (crispy-server)

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Liveness probe |
| `GET /proxy?url=<url>` | CORS relay proxy (images, M3U8, TS segments) |
| `GET /ws` | WebSocket command protocol |

Protocol: `{"cmd":"loadChannels","id":"req-1"}` → `{"id":"req-1","data":[...]}`

## Configuration

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dart deps (Riverpod 3.2.1, media_kit 1.1.11, dio 5.7.0, go_router 17.1.0) |
| `rust/Cargo.toml` | Rust workspace (Edition 2024, reqwest, rusqlite, aes-gcm, argon2) |
| `assets/config/app_config.json` | Runtime config (version, API host/port, cache limits, feature flags) |
| `analysis_options.yaml` | Dart linting (flutter_lints) |
| `flutter_rust_bridge.yaml` | FFI codegen config |
| `flutter_launcher_icons.yaml` | Platform icon generation |
| `l10n.yaml` | Localization configuration |
| `lefthook.yml` | Pre-commit hook orchestration |
| `.riceguard.yaml` | Code quality rules |

## Key Dependencies

### Dart

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_riverpod | 3.2.1 | State management |
| media_kit | 1.1.11 | Video playback engine |
| dio | 5.7.0 | HTTP client |
| go_router | 17.1.0 | Navigation routing |
| google_fonts | 8.0.1 | Outfit + Inter typography |
| flutter_rust_bridge | 2.11.1 | FFI bridge |
| window_manager | 0.5.1 | Desktop window control |
| flutter_animate | 4.5.2 | Animations |
| audio_service | 0.18.15 | Background audio (SMTC, MPRIS) |
| shared_preferences | 2.3.3 | Local storage |
| google_sign_in | 6.2.2 | Google Drive backup |
| webdav_client | 1.2.2 | WebDAV sync |
| dartssh2 | 2.8.3 | SSH support |
| mocktail | 1.0.4 | Test mocking |

### Rust

| Crate | Purpose |
|-------|---------|
| rusqlite + r2d2 | SQLite + connection pool |
| reqwest | HTTP client (rustls-tls, gzip) |
| aes-gcm | AES-256-GCM encryption |
| argon2 | Argon2id PIN hashing |
| flutter_rust_bridge (2.11.1) | FFI code generation |
| axum | WebSocket server |
| serde + chrono + uuid | Serialization, time, IDs |
| tokio | Async runtime |
| wiremock + mockall + insta + proptest | Test frameworks |

## Documentation (.ai/)

| Doc | Purpose |
|-----|---------|
| `.ai/docs/project-specs/ui_ux_spec.md` | Feature matrix + implementation status |
| `.ai/docs/project-specs/design_system.md` | Color tokens, typography, spacing, components |
| `.ai/docs/project-specs/ux_workflows.md` | Navigation flows, user interaction patterns |
| `.ai/docs/project-specs/conversion_plan.md` | Migration roadmap + progress |
| `.ai/docs/project-specs/video_upscaling_spec.md` | GPU upscaling & super resolution |
| `.ai/docs/project-specs/platform_targets.md` | Platform support matrix |
| `.ai/planning/REQUIREMENTS.md` | 1,329 requirements across 29 categories |
| `.ai/planning/USER-JOURNEYS.md` | 47 user journey specifications |
| `.ai/SRS.md` | Software Requirements Specification |
| `.ai/crispy_tivi_design_spec.md` | Master design specification |

## Test Coverage

| Layer | Files | Tests | Framework |
|-------|-------|-------|-----------|
| Unit/Widget | 260 | 3,600+ | flutter_test + mocktail |
| Golden/Visual | 16 tests, 20 baselines | pixel regression | flutter_test |
| Integration | 38 files, 16 flows | 27+ flows | integration_test (Windows/Android) |
| Playwright E2E | 13 spec files | 60+ | Playwright (4 viewports) |
| Rust tests | inline + integration | 1,258+ | cargo test + insta + proptest |
| Performance | 4 files | benchmarks | Custom |
| **Targets** | | | Dart ≥85%, Rust ≥90% |

### Test Infrastructure

| What | Where |
|------|-------|
| Unit/widget tests | `test/` (260 files) |
| Golden baselines | `test/golden/goldens/` (20 images) |
| Golden failures | `test/golden/failures/` (gitignored) |
| Integration flows | `integration_test/flows/` (16 files) |
| Page objects | `integration_test/robots/` (6 robots) |
| Playwright tests | `e2e/playwright/tests/` (13 specs) |
| Playwright config | `e2e/playwright/playwright.config.ts` |
| CI pipeline | `.github/workflows/ci.yml` |

### CI Pipeline Tiers

- **Tier 0** (required, fast): Rust fmt/clippy/test, Flutter analyze/test
- **Tier 1** (required for merge): Golden tests, Windows/Android/Web builds, Playwright, server build
- **Tier 2** (advisory): Linux, macOS, iOS builds
- **Thresholds**: Rust ≥1,195 tests, Flutter ≥3,600 tests

## Architecture Boundaries (MANDATORY)

- **Rust owns**: ALL business logic, parsing, DB, crypto, sync, algorithms
- **Flutter owns**: ALL UI rendering, animations, navigation, theming
- **FFI bridge**: Type-safe JSON communication via flutter_rust_bridge
- **Cache layer**: CacheService is the ONLY Dart-side data access (providers never call FFI directly)
- **Event-driven**: Rust DataChangeEvent → eventDrivenInvalidator → Riverpod provider invalidation
- **Triple backend**: FFI (production), Memory (test), WebSocket (web/debug) — all interchangeable

## Platform Targets

Desktop (Windows, macOS, Linux), Android (Phone, Tablet, TV/Fire TV), iOS, Web, Samsung Tizen, WebOS

### Responsive Breakpoints

| Class | Width | Layout |
|-------|-------|--------|
| compact | <600dp | Bottom nav bar (phones) |
| medium | 600-839dp | Transitional (tablets portrait) |
| expanded | 840-1199dp | Side rail (tablets landscape, small desktop) |
| large | ≥1200dp | Full side rail + two-panel (desktop, TV) |

## Build Scripts

| Script | Purpose |
|--------|---------|
| `scripts/build_rust.sh` | Cross-platform Rust compilation |
| `scripts/build_appimage.sh` | Linux AppImage packaging |
| `scripts/inno_setup.iss` | Windows installer |
| `scripts/wsl_build_linux.sh` | Linux build via WSL |
| `scripts/check_boundary.dart` | Architecture boundary validation |
| `Makefile` | Developer convenience commands |

## Quick Start

```bash
# Install deps
flutter pub get

# Run on desktop
flutter run -d windows

# Run web (needs Rust backend)
cd rust && cargo run -p crispy-server --release &
flutter run -d chrome --web-port 3000

# Run tests
flutter test                                              # Unit/widget
flutter test integration_test/app_test.dart -d windows    # Integration
cd e2e/playwright && npx playwright test                  # E2E (after build)

# Format (mandatory before commit)
dart format lib/ test/
cd rust && cargo fmt --all
```

## File Statistics

| Metric | Count |
|--------|-------|
| Total .dart files (lib/) | 790 |
| Total .dart files (test/) | 260 |
| Total .dart files (integration_test/) | 38 |
| Total .rs files | 301 |
| Rust LOC | ~82,665 |
| Features | 20 |
| Core widget components | 75 |
| FFI API modules | 19 |
| DB migrations | 9 |
| Localization languages | 9 |
| Golden baselines | 20 |
| Design token files | 11 |
