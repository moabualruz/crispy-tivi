# Crispy-Tivi V1 Phase Roadmap

**Principle — nothing is post-V1.** Every feature the project cares about ships in V1. Some items land early (foundation), some land in the MVP, and some land in the V1 late phase before release. But the V1 feature set is **complete**, not a subset of a bigger future version.

This document supersedes the "extensibility" framing in SPEC-RAW §21. Per [decisions.md](decisions.md) D16, every item in that section is a V1 late-phase feature.

All items here must ship **before V1 release**.

---

## Phase 1 — Foundation

Built first. Feature work cannot meaningfully start until these are in place.

### 1.1 Monorepo and build
- ✅ Gradle wrapper pinned to 9.4.1; JDK 21 toolchain enforced
- ✅ Version catalog (`gradle/libs.versions.toml`) as single source of truth
- ✅ `build-logic/` convention plugins (`crispy.kmp.library`, `crispy.kmp.feature`, `crispy.android.application`) to eliminate per-module boilerplate
- ✅ All 50 modules scaffolded per [monorepo-blueprint.md](monorepo-blueprint.md)
- ✅ Android SDK wired via AGP 9.1 + new `com.android.kotlin.multiplatform.library` plugin
- Layer on iOS / wasmJs / Compose Desktop targets in the conventions once their toolchains are on the build host
- Wire `:app:ios` to produce an iOS framework, `:app:desktop` to the Compose Desktop application plugin, `:app:web` to the Compose/wasmJs application plugin

### 1.2 Shared architecture
- `:domain:model` — normalized entities from [data-model.md](data-model.md)
- `:domain:services` — EPG matcher, dedup, selection, ranking, source merge (contracts only in phase 1; implementations drop in Phase 2)
- `:domain:policies` — autoplay/restore/stale/merge/refresh policy objects
- `:data:contracts` — every repository/service/facade interface from [contract-api-spec.md](contract-api-spec.md)
- `:core:navigation` — **hand-rolled** navigation (sealed `AppDestination` + `BackStack` `StateFlow` + `Navigator`); see [open-questions.md](open-questions.md) R1
- `:data:restoration` — `RestorationRecord` persistence + hydration; integrated with `:core:navigation`
- `error-model` — typed error families (provider, platform, feature, persistence, playback, sync)
- `observability-contracts` — structured logger, metrics, traces

### 1.3 Playback foundation
- `:core:playback` — `PlaybackBackend` interface, `PlaybackFacade`, `PlaybackSelectionService`, `MediaSessionController` contract
- `:platform:player:android` — Media3 / ExoPlayer binding
- `:platform:player:apple` — AVPlayer cinterop binding
- `:platform:player:desktop` — **R2 research task** — pick libVLC/vlcj vs libmpv vs FFmpeg, then bind
- `:platform:player:web` — hls.js via Kotlin/JS externals
- Round-trip `PlayerState` / `PlayerEvent` across all four backends through the shared contract

### 1.4 Design system
- `:core:design-system` module initialized
- Token taxonomy **designed fresh** from [uiux-spec.md](uiux-spec.md) §5 per D8. No carryover from the deprecated Flutter token JSON
- Color roles (dark + cool-toned; cyan/ice-blue focus; restrained violet; crimson for live/urgent; no gold/yellow)
- Text roles, spacing scale, radius/shape scale, elevation scale, icon scale
- Focus / selection state styling (focused > selected)
- Motion tokens (calm, short, controlled — no bounce)
- Panel / card / input-state variants
- Compose Multiplatform wiring so features consume tokens only

### 1.5 Persistence foundation
- SQLDelight 2.3.2 integration in `data-*` modules
- Schema draft per [db-schema-guide.md](db-schema-guide.md)
- FTS5 virtual tables for search
- Migration strategy + schema versioning
- `platform-security-*` per [decisions.md](decisions.md) D10: Android Keystore, Apple Keychain (iOS + macOS), Desktop DPAPI/libsecret, Web Crypto + IndexedDB

### 1.6 Observability foundation
- `:data:observability` — structured log emission, local storage, correlation IDs, trace spans
- `platform-observability-*` — per-platform log sinks

---

## Phase 2 — Core MVP

Everything required for a usable IPTV app. When Phase 2 is done, a user can onboard a source, browse, search, play, and come back later.

### 2.1 Source ingestion
- `:provider:m3u` — hand-rolled Extended-M3U parser (R4)
- `:provider:xtream` — hand-rolled Xtream Codes REST client (R4)
- `:provider:stalker` — hand-rolled Stalker / Ministra portal client (R4)
- Provider adapter factory in `:provider:contracts`
- Source validation, configuration persistence, credential binding through `SecretStore`
- `:feature:sources` — UI for add/edit/remove/enable/disable/validate

### 2.2 Onboarding gate
- `:feature:onboarding` — required first-run flow per PBS §8
- Blocks browse/play until initial sync completes
- Progress indication during sync
- Error recovery if source validation fails

### 2.3 Sync pipeline
- `:data:sync` — `SyncFacade`, `SyncScheduler`, `SyncPolicy`, `SyncObserver`
- Onboarding sync (blocking) + ongoing refresh (non-blocking)
- UPSERT-based persistence
- Partial refresh support
- Retry/backoff
- Stale-state awareness

### 2.4 Normalization and aggregation
- `:data:normalization` — provider payload → normalized entities
- Source-scoped and aggregate identity per [data-model.md](data-model.md)
- Deduplication strategy (strategy pattern behind `DeduplicationStrategy`)
- Multi-source browse support

### 2.5 Browse features
- `:feature:home` — landing: hero + rails (Continue Watching, Live Now, Recently Added Movies/Series, etc.)
- `:feature:live` — channel browsing per UIUX §8.2: source/group navigation + channel list + context panel
- `:feature:guide` — EPG timeline/grid per UIUX §8.3
- `:feature:movies` — movie catalog per UIUX §8.4
- `:feature:series` — series/season/episode per UIUX §8.5
- `:feature:search` — cross-source search per UIUX §8.6
- `:feature:library` — personal return points per UIUX §8.7: Continue Watching, Favorites, History, Saved positions, Recently Played Channels
- `:feature:settings` — configuration per UIUX §8.8

### 2.6 EPG
- `:core:epg` — XMLTV streaming pull parser (hand-rolled using Okio from SQLDelight/Ktor transitive dep) per R4
- `epg_programs` + `epg_channels` + `epg_mapping_candidates` tables
- Runtime channel matching with `EpgMatcher` strategy
- `EpgScheduleResolver` for current/next/window resolution
- On-demand EPG from Xtream/Stalker where provider supports it

### 2.7 Search
- `:data:search` — FTS5-backed indexed search per SPEC Amendment D
- `SearchIndexer` + `SearchService` + `SearchRankingStrategy`
- Source/content-type/filter support
- Query ranking: textual relevance, exact/phrase > loose, title > metadata, quality signals as tiebreaker

### 2.8 Playback
- `:feature:player` — playback surface, layered OSD per UIUX §9
- Media3/AVPlayer/desktop/hls.js backends wired end-to-end
- Source switching between variants of a merged aggregate entity
- `ResolvedPlaybackSelection` flow
- Live restoration autoplay per [decisions.md](decisions.md) D11

### 2.9 Media session
- Per-platform `MediaSessionController` implementations per R5
- Now-playing metadata publication
- Media key / remote command handling
- Lock screen / system surface integration
- Audio focus + interruption handling

### 2.10 Image pipeline
- `:core:image` — `ImageLoaderContract`, `ImagePolicy`, `ArtworkResolver`
- Coil 3 integration (already in catalog) with disk-first cache policy
- Bounded memory cache
- Off-screen cancellation
- Downsampling / fallback placeholders

### 2.11 Restoration
- `:data:restoration` — `RestorationService` + `RestorationPolicy` + `RestorationRecorder`
- Navigation restoration (from `:core:navigation`), playback restoration, contextual return flows
- Survives config change, app recreation, process death (per-platform via platform-specific save containers)

### 2.12 Import / export
- `:core:export-import` — `BackupExporter`, `BackupImporter`, `BackupFormatCodec`, `ImportMergePolicy`
- Format: ZIP of JSON documents per [decisions.md](decisions.md) D12 (manifest.json + sources.json + favorites.json + history.json + settings.json + restoration.json + optional epg-config.json)
- Secrets: excluded by default, opt-in encrypted via Argon2id + AES-GCM with user passphrase
- Version schema + merge/replace modes
- File pickers on each platform

### 2.13 Diagnostics
- `DiagnosticsBundleExporter` for local diagnostic export
- Development-mode inspection surfaces
- Local trace/log correlation

---

## Phase 3 — V1 Late-phase features

**Formerly "extensibility" in SPEC-RAW §21 — reclassified as V1 per D16.** Every item here ships in V1, just after the Phase 2 MVP is stable. None of them block Phase 2.

### 3.1 Subtitles
- Subtitle track selection (WebVTT, TTML, SRT, SubRip, SSA/ASS where player supports)
- Subtitle styling (font size, color, edge, background)
- Subtitle timing offset (delay/advance)
- Per-platform: Media3 handles Android; AVFoundation handles Apple; desktop backend from R2; `<track>` elements for hls.js on Web

### 3.2 Audio track selection
- Audio track picker in player OSD
- Audio language preference policy
- Per-platform support via each backend's native API

### 3.3 Picture-in-picture
- Android: Media3 PiP support + `enterPictureInPictureMode`
- iOS: AVPlayerViewController PiP
- Desktop: floating always-on-top window via Compose Desktop window APIs
- Web: browser Picture-in-Picture API via `<video>` element (Chrome / Safari / Firefox)

### 3.4 Background playback
- Policy already in [platform-behavior.md](platform-behavior.md) §12 and SPEC Amendment I
- Android: Foreground service + Media3 session
- iOS: Audio session category `playback` + background modes entitlement
- Desktop: keep app running + mini controls
- Web: Page Visibility API + Media Session API keeps audio playing
- Consistent resume-after-interruption behavior

### 3.5 Catch-up / Archive support
- Provider-level catch-up support detection (Xtream `tv_archive`, Stalker archive endpoints, XMLTV catch-up URLs)
- `CatchupSelection` normalized model: live channel + catch-up time window
- UI: "Watch from beginning" / "Watch X minutes ago" actions on live channels with archive
- Requires EPG alignment for accurate time mapping
- Playback routes through same `PlaybackBackend` contract (just different URL templates per provider)

### 3.6 Recording (local + provider-side where supported)
- **Local recording** (desktop and Android): capture the stream into a local file via the active backend
  - libVLC/libmpv/FFmpeg all support direct stream dumping
  - Media3 has `DownloadHelper` for OTA-style downloads
- **Provider-side recording** where the IPTV source has its own DVR (some Xtream deployments)
- `RecordingStrategy` pattern so behavior can be per-source
- UI in `:feature:library`: Recordings section
- File management: rotation, storage quota, cleanup policy

### 3.7 Parental controls
- PIN gate on app launch (optional)
- Per-category content filter (block by rating, category, channel)
- Per-source visibility toggle (child account sees only kid-friendly sources)
- Stored in `settings` table with a scope enum (`GLOBAL`, `PROFILE`)
- UI in `:feature:settings`: Parental Controls bucket

### 3.8 Casting (Google Cast + AirPlay + DLNA)
- See [open-questions.md](open-questions.md) R6 for the full architecture
- New modules added in Phase 3: `cast-core`, `platform-cast-android`, `platform-cast-apple`, `platform-cast-desktop`, `platform-cast-web`
- Google Cast Sender SDK on Android
- Native AirPlay on iOS/macOS via AVPlayer `allowsExternalPlayback`
- Hand-rolled Chromecast + DLNA on desktop
- Browser Remote Playback API on Web
- Cast button appears in the player OSD when a cast device is discovered

### 3.9 Richer provider capabilities
- Catch-up URL templates (per-provider customization)
- Multi-stream quality selection (HLS variant picker)
- Provider-specific metadata enrichment (artwork, descriptions)
- Provider health dashboards in `:feature:sources`

### 3.10 Richer account management
- Multiple user profiles (per-profile favorites / history / settings / parental rules)
- Profile picker on launch
- Per-source credential rebinding flows
- Credential rotation UI

### 3.11 Tablet / TV form-factor refinement
- Baseline responsiveness already in Phase 1 via `:core:design-system` scales
- Phase 3 adds: TV-specific focus / overscan handling, tablet-specific side-panel layouts, phone-landscape density tuning
- No separate portrait/mobile paradigm per [uiux-spec.md](uiux-spec.md) §14

---

## Phase 4 — V1 Release polish

Final polish before shipping V1 on all six platforms.

### 4.1 Cross-platform parity audit
- Every Phase 2 + Phase 3 feature exercised on every platform
- Android: phone + tablet + Android TV
- iOS: phone + iPad
- Desktop: Windows + macOS + Linux (at least one distro each)
- Web: Chrome + Safari + Firefox + Edge

### 4.2 Performance tuning
- Virtualization audit across all large surfaces (channel lists, guide grids, poster rails, search results)
- Image pipeline memory profiling
- EPG ingestion throughput (large XMLTV files)
- Cold-start time per platform
- Long-session memory stability

### 4.3 Accessibility pass
- Contrast, focus visibility, hit target sizes per [uiux-spec.md](uiux-spec.md) §15
- Screen reader labels on all actionable elements
- Keyboard-only operation parity with remote/gamepad

### 4.4 Diagnostic bundle finalization
- Exported diagnostic format versioned and schema-validated
- Redaction of secrets across logs, metrics, traces

### 4.5 Release artifacts
- Android: AAB signed for Play Store + standalone APK for sideload distribution
- iOS: IPA + App Store build
- Desktop: Windows MSI / macOS DMG / Linux AppImage + deb + rpm (or whichever we settle on)
- Web: static bundle + SPA host config

### 4.6 Documentation
- Per-subsystem README for every volatile module (source normalization, EPG matching, playback selection, sync pipeline, restoration, search indexing, import/export)
- Release notes
- Upgrade/migration notes for future versions

---

## Cross-cutting concerns (applied throughout all phases)

- **Remote/gamepad/keyboard parity** — every primary workflow must work with D-pad/gamepad/keyboard from day one. Pointer is optional enhancement.
- **Source-agnostic UI** — no provider DTO ever reaches a feature module.
- **Virtualized rendering** — every potentially-unbounded surface uses lazy/windowed composition from day one. Never "optimize later".
- **Typed errors** — raw exceptions are mapped at module boundaries; feature code only sees typed error families.
- **Testing** — strategies / policies / facades / normalization / dedup / ranking / restoration / sync decisions all have direct unit tests. No coverage-theater tests.
- **Observability** — every subsystem emits structured logs and correlation IDs from its first commit. Diagnostics are built in, not retrofitted.

---

## What is NOT in V1

Literally nothing the spec mentions. Per D16, the SPEC-RAW §21 "Extensibility Requirements" section no longer defines a post-V1 bucket. If anything new appears that can't fit in Phase 3, it must be explicitly added to this document with a rationale — there is no invisible "V2" folder.
