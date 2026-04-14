# Crispy-Tivi

Cross-platform IPTV media app — one application on Android, iOS, Windows, macOS, Linux, and Web. Built as a Kotlin Multiplatform + Compose Multiplatform monorepo.

**Status:** Scaffolding. No feature code yet. See [docs/v1-phase-roadmap.md](docs/v1-phase-roadmap.md) for the V1 plan.

## What it does (V1 scope)

- Multi-source IPTV ingestion: M3U / Extended-M3U, Xtream Codes, Stalker / Ministra portals
- XMLTV EPG ingestion (streaming parser for multi-hundred-MB files)
- Live channels, VOD movies, VOD series (season/episode)
- Cross-source search with SQLite FTS5
- Normalized source-agnostic browse with source-aware filtering
- Remote / gamepad / keyboard-first navigation
- Local SQLite + SQLDelight persistence, native secure storage per platform
- Disk-first image pipeline
- Layered restoration (config change, process death, app relaunch)
- Import / export to a versioned ZIP-of-JSON backup with opt-in passphrase-encrypted secrets
- V1 late-phase: subtitles, audio tracks, PiP, background playback, catch-up/archive, recording, Google Cast + AirPlay + DLNA casting, parental controls, multi-profile

Nothing is post-V1. Every planned feature ships in V1 per [docs/v1-phase-roadmap.md](docs/v1-phase-roadmap.md).

## Stack

- Kotlin 2.3.20, Gradle 9.4.1, AGP 9.1.0 (`com.android.kotlin.multiplatform.library` for KMP modules)
- Compose Multiplatform 1.10.3 (Android, iOS, desktop, web)
- Ktor 3, kotlinx.coroutines, kotlinx.serialization, kotlinx.datetime
- SQLDelight 2.3.2 + FTS5
- Coil 3, Koin 4, Kermit, Turbine, Kotest
- Media3 / ExoPlayer (Android), AVPlayer cinterop (Apple), desktop backend TBD, hls.js externals (Web)
- Hand-rolled: navigation, XMLTV parser, provider clients (M3U / Xtream / Stalker), per-platform media session, casting integration (see [docs/open-questions.md](docs/open-questions.md))

## Build

Requires JDK 21. Android SDK is optional for non-Android targets; required for `:app:android`.

```bash
./gradlew build                  # full project build
./gradlew :app:android:assembleDebug
./gradlew :domain:model:compileKotlinJvm
./gradlew projects               # list the module tree
```

Machine-local Android SDK path goes in `local.properties` (gitignored):

```properties
sdk.dir=/path/to/your/android-sdk
```

## Repository layout

```
crispy-tivi/
├── app/                  # app-* shells (android, ios, desktop, web)
├── build-logic/          # Gradle convention plugins
├── core/                 # design-system, navigation, playback, epg, image, security, export-import
├── data/                 # contracts, repositories, normalization, search, sync, restoration, observability
├── docs/                 # requirements, decisions, roadmap, open questions, ADRs, code standards
├── domain/               # model, services, policies
├── feature/              # home, live, guide, movies, series, search, library, sources, settings, player, onboarding
├── gradle/               # wrapper + libs.versions.toml
├── platform/             # platform-specific integrations
│   ├── player/           # android, apple, desktop, web
│   ├── security/         # android, apple, desktop, web
│   └── observability/    # android, apple, desktop, web
├── provider/             # contracts, m3u, xtream, stalker
├── test/                 # fixtures, contracts
├── AGENTS.md             # guidance for coding agents (Claude Code, Copilot CLI, etc.)
├── README.md
├── LICENSE
├── .editorconfig
├── .gitignore
├── settings.gradle.kts
├── build.gradle.kts
└── gradle.properties
```

## Start here

1. [docs/Requirements.md](docs/Requirements.md) — index of every requirements document
2. [docs/decisions.md](docs/decisions.md) — 17 resolved decisions (authoritative; wins any conflict)
3. [docs/v1-phase-roadmap.md](docs/v1-phase-roadmap.md) — V1 feature phasing
4. [docs/code-standards.md](docs/code-standards.md) — mandatory coding standards
5. [docs/monorepo-blueprint.md](docs/monorepo-blueprint.md) — module layout and boundaries
6. [docs/open-questions.md](docs/open-questions.md) — hand-roll architecture sketches + the single remaining research task (R2 desktop playback backend)

## License

See [LICENSE](LICENSE).
