# Crispy-Tivi — Resolved Decisions

This file records the decisions made during the interview that resolved conflicts and gray areas across the suggestive-context documents. Each decision supersedes whatever the source docs said, and the affected sections in the other context files have been updated accordingly.

When this file conflicts with a source document, this file wins.

---

## D1 — Module layout

**Decision:** Use the REPO-BLUEPRINT fine split as the authoritative starting module graph.

Top-level modules:

```
app-android, app-ios, app-desktop, app-web

design-system, navigation-core

feature-home, feature-live, feature-guide, feature-movies, feature-series,
feature-search, feature-library, feature-sources, feature-settings,
feature-player, feature-onboarding

domain-model, domain-services, domain-policies

data-contracts, data-repositories, data-normalization, data-search,
data-sync, data-restoration, data-observability

provider-contracts, provider-m3u, provider-xtream, provider-stalker

epg-core, playback-core, image-core, security-core, export-import-core

platform-player-android, platform-player-apple, platform-player-desktop, platform-player-web
platform-security-android, platform-security-apple, platform-security-desktop, platform-security-web
platform-observability-android, platform-observability-apple, platform-observability-desktop, platform-observability-web

test-fixtures, test-contracts
```

Notes:
- `:platform:player:apple` covers both iOS and macOS (shared AVPlayer/AVFoundation code).
- `:platform:security:apple` covers both iOS and macOS Keychain. `:platform:security:desktop` covers Windows (DPAPI) and Linux (libsecret/D-Bus) only.
- `:platform:observability:apple` covers iOS and macOS. `:platform:observability:desktop` covers Windows, macOS-specific desktop observability if needed, and Linux — follow REPO-BLUEPRINT's original listing.
- SPEC-RAW §6's coarser `core-*` layout is superseded.
- REPO-BLUEPRINT §9 safe-early-merge guidance still applies when a module is too small to justify its own Gradle target.

**Affected:** SPEC-RAW §6 → removed; REPO-BLUEPRINT §2 → restored with this resolved list.

---

## D2 — Feature module decomposition

**Decision:** 11 feature modules aligned with the UIUX primary destinations plus onboarding/player/settings/sources:

- `:feature:home`
- `:feature:live`
- `:feature:guide`
- `:feature:movies`
- `:feature:series`
- `:feature:search`
- `:feature:library`
- `:feature:sources`
- `:feature:settings`
- `:feature:player`
- `:feature:onboarding`

SPEC-RAW's compact set (`feature-channels`, `:feature:library` as VOD, `feature-epg`) is superseded. The renamings come from D4 (`feature-channels` → `:feature:live`) and D5 (`feature-epg` → `:feature:guide`).

**Affected:** SPEC-RAW §15 feature list → superseded; REPO-BLUEPRINT §3.3 → restored.

---

## D3 — Meaning of "Library"

**Decision:** `Library` (and `:feature:library`) means **personal return points**: Continue Watching, Favorites, History, Saved positions, Recently Played Channels, and source-scoped saved content. UIUX §8.7 is canonical.

VOD catalog browsing lives in `:feature:movies` and `:feature:series`. SPEC-RAW §15.3's VOD-catalog meaning is renamed to "Catalog" wherever it appears as a noun:

- SPEC-RAW §10: "media-library playback" → "media catalog playback"
- SPEC-RAW §12: "VOD/library entities" → "VOD/catalog entities"
- SPEC-RAW §15.3: re-titled "Catalog (Movies and Series)" and scoped to the feature-movies/feature-series modules
- PBS §14: "library browsing" → "catalog browsing"

**Affected:** SPEC-RAW §10, §12, §15.3; PBS §14; UIUX §8.7 (restored).

---

## D4 — `:feature:live` naming

**Decision:** The live-channel feature module is `:feature:live`. SPEC-RAW's `feature-channels` is renamed.

UI destination: "Live". Underlying entity: channel. Module name follows the destination.

---

## D5 — `:feature:guide` naming

**Decision:** The EPG/guide feature module is `:feature:guide`. SPEC-RAW's `feature-epg` is renamed.

The data-layer term "EPG" stays (epg-core module, `EpgMatcher`, `EpgScheduleResolver`, `epg_programs` tables, etc.) — only the feature module and UI destination use "Guide".

---

## D6 — Provider modules are split per family

**Decision:** Four provider modules: `:provider:contracts`, `:provider:m3u`, `:provider:xtream`, `:provider:stalker`. Each provider module owns its parser/mapper/adapter/model. `:provider:contracts` owns `SourceAdapter`, `SourceCapabilities`, `SourceAdapterFactory`, and DTO boundary contracts.

Future additions (Jellyfin, Emby, etc.) get their own `provider-<name>` module. SPEC-RAW's monolithic `core-sources` is superseded.

---

## D7 — Player backend module naming

**Decision:**

- Prefix: `platform-player-*` (matches sibling `platform-security-*` and `platform-observability-*`).
- Apple module: `:platform:player:apple` covers both iOS and macOS via shared AVPlayer/AVFoundation code behind the `:core:playback` `PlaybackBackend` contract.
- Web: dedicated `:platform:player:web` module owns the hls.js integration and implements `:core:playback` contracts. Does not live inside `:app:web`.

Full list: `:platform:player:android`, `:platform:player:apple`, `:platform:player:desktop`, `:platform:player:web`.

---

## D8 — `a-design-try-not-bad-but-not-good-either/` folder

**Decision:** Reference-only. Flutter is dead.

- All Flutter code paths (`app/flutter/lib/...`), Penpot manifests, Widgetbook specimens, and Dart token files are deprecated. They must not inform implementation decisions in the Compose/KMP project.
- The folder stays in the repo as historical reference but is not copied into `context/`.
- `sample-but-wrong-color-and-logo.png` is not the target visual direction (the filename itself says so).

**Token taxonomy for the Compose design system will be designed fresh.** The prior Flutter token JSON families are NOT used as a starting point. The new token taxonomy is derived from UIUX §5.1 categories against UIUX §4 mood:

- color roles (dark, cool-toned; cyan/ice-blue focus; restrained violet secondary; crimson only for urgent/live; no gold/yellow as primary accent)
- text roles
- spacing scale
- radius/shape scale
- elevation/layering scale
- icon scale
- focus styles (focused state must be visually stronger than selected state)
- selection styles
- motion timing / easing
- panel/card variants
- input-state variants

---

## D9 — Web is a first-class V1 target

**Decision:** Web ships in V1 with full feature parity except where browser APIs make parity impossible (orientation lock, Keystore-equivalent, some filesystem access). SPEC-RAW §2's "secondary target" classification is superseded. ARD ADR-001/ADR-002 and PBS §2 are reinforced.

---

## D10 — Secure storage plan for all platforms

**Decision:** Native secure storage per platform family behind the `:core:security` `SecretStore` contract.

- `:platform:security:android` — Android Keystore-backed.
- `:platform:security:apple` — iOS and macOS Keychain-backed (shared code).
- `:platform:security:desktop` — Windows (DPAPI) and Linux (libsecret via D-Bus). macOS desktop goes through `:platform:security:apple`, not this module.
- `:platform:security:web` — Web Crypto (subtle crypto) + IndexedDB, storing an encrypted blob. Master key derived from a device-scoped identifier.

The database stores `SecretRef` values only; plaintext credentials never live in the main app DB. REPO-BLUEPRINT §3.8 is extended to include the two new modules.

---

## D11 — Autoplay-on-relaunch default for live channels

**Decision:** Autoplay is **on by default** when the app relaunches with a live channel as the last playback target. The policy remains configurable via the `AutoplayRestorePolicy` object, and users can disable it in Settings → Playback.

Movies and episodes still restore only the details context and do NOT autoplay on relaunch (SPEC-RAW Amendment C and PBS §10 remain authoritative for VOD).

---

## D12 — Backup/export format and secret policy

**Decision:**

**Format:** ZIP of JSON documents. One `.crispytivi` backup file contains:
- `manifest.json` (version, created-at, source-app-version, included-domains)
- `sources.json`
- `favorites.json`
- `history.json`
- `settings.json`
- `restoration.json`
- optional `epg-config.json`, `cache-metadata.json`
- optional `secrets.enc` (see below)

**Secret policy:** secrets are **excluded by default**. During export the user is asked whether to include them; if yes, credentials are encrypted with Argon2id-derived key + AES-GCM using a user-supplied passphrase and written as `secrets.enc` inside the ZIP. The passphrase is never stored. Import prompts for the passphrase only if `secrets.enc` is present.

SPEC-RAW Amendment K's three options are resolved to the ZIP-of-JSONs choice.

---

## D13 — Navigation/state pattern (DEFERRED)

**Decision:** **Phase-1 research task.** No framework is pinned yet.

Phase 1 runs a focused spike comparing:
- Decompose + MVIKotlin
- Voyager
- Jetpack Compose Navigation Multiplatform

against these acceptance criteria:
- typed routes
- survives config change + process death on Android
- state restoration on iOS / desktop / web
- integration with `:data:restoration` and the `RestorationRecord` model
- remote/gamepad/keyboard navigation parity

The winner is committed before any feature-level navigation work starts. SPEC-RAW §23.2 remains open until then.

---

## D14 — Desktop playback backend (DEFERRED)

**Decision:** **Phase-1 research task.** No backend is pinned yet. SPEC-RAW Amendment B (libVLC/vlcj) and ARD ADR-007's desktop line are both downgraded to "proposed — subject to research outcome".

Phase 1 runs a focused spike comparing at least:
- libVLC via vlcj
- JavaFX MediaPlayer
- JavaCV / FFmpeg bindings
- mpv bindings

against IPTV-oriented acceptance criteria (HLS/TS live streams, subtitles, track selection, state observation, fullscreen, error propagation, cross-platform Windows/macOS/Linux). The shared player contract in `:core:playback` stays stable regardless of the backend chosen, so `:platform:player:desktop` can switch implementations without affecting feature code.

Until the research lands, `:platform:player:desktop` is a stub that fails fast with a clear error.

---

## D15 — V1 ships on all six platforms

**Decision:** Android, iOS, Windows, macOS, Linux, Web all ship V1. No phased platform rollout. Aligns with ARD ADR-001, ADR-002, PBS §2, and D9.

---

## D16 — Nothing is post-V1; SPEC-RAW §21 "extensibility" is V1 late-phase

**Decision:** The V1 feature set is **complete**. Every feature the project mentions ships in V1. SPEC-RAW §21 "Extensibility Requirements" is reclassified from "post-V1 extensibility" to "V1 late-phase features". V1 is divided into four phases — foundation, core MVP, late-phase features, release polish — see [v1-phase-roadmap.md](v1-phase-roadmap.md).

Items reclassified into V1 late phase (Phase 3):
- subtitle controls (select + style + timing offset)
- audio track selection
- picture-in-picture (all six platforms)
- background playback (already partly required by PBS §12 — now fully in)
- catch-up / archive support
- recording (local + provider-side where supported)
- casting (Google Cast + Apple AirPlay + DLNA — see R6)
- parental controls
- richer provider capabilities
- richer account management (multi-profile)
- tablet / TV form-factor refinement

**Why:** the prior "extensibility" framing implicitly permitted deferring these to a V2. That's no longer the plan — either a feature ships in V1 (possibly late), or it doesn't exist.

**How to apply:** when scoping any sprint, never treat §21 items as optional. They are V1 commitments with Phase 3 timing. If something truly cannot fit into V1, it must be explicitly added to [v1-phase-roadmap.md](v1-phase-roadmap.md) with rationale — there is no invisible backlog.

**Affected:** SPEC-RAW §21 header (marked as V1 late-phase); new file [v1-phase-roadmap.md](v1-phase-roadmap.md); open-questions.md R6 (casting architecture).

---

## D17 — Hand-roll policy: drop ill-maintained or single-platform libraries

**Decision:** If a dependency is ill-maintained (stale releases, single-maintainer bus factor, pre-1.0 with no roadmap) **or** fails to cover all six V1 target platforms gracefully, we drop it and implement the subsystem ourselves.

**Dropped in the April 2026 audit:**

| Library | Role | Reason dropped |
|---|---|---|
| Decompose | KMP navigation | Single-maintainer (bus-factor 1 on a load-bearing subsystem) |
| Voyager | KMP navigation | Last stable 1.0.1 is stale; active work is in 1.1.0-beta |
| androidx.navigation.compose | navigation | KMP-stable only on Android |
| MediaMP | KMP player wrapper | Single-maintainer, core still 0.0.x |
| kdroidFilter ComposeMediaPlayer | KMP player wrapper | Single-maintainer |
| Chaintech compose-multiplatform-media-player | KMP player wrapper | Reels/YouTube-oriented API, wrong domain |
| mediasession-kt (toastbits) | desktop media session | Single-maintainer, missing macOS and Web |
| xmlutil + xmlutil-serialization | KMP XML for XMLTV | Single-maintainer; XMLTV is a narrow DTD we can pull-parse with Okio |
| saifullah-nurani/XtreamApi | Xtream API client | Pre-1.0, single-maintainer, missing native-desktop + Web targets |

**What we hand-roll instead** (detailed in [open-questions.md](open-questions.md) R1, R3, R4, R5):

- Navigation + back stack + restoration → `:core:navigation` (sealed `AppDestination` + `StateFlow<BackStack>` + `RestorationRecord` integration)
- KMP `PlaybackBackend` contract → `:core:playback` + per-platform impls in `platform-player-*` directly on Media3 / AVPlayer / R2-chosen desktop backend / hls.js
- Media session on non-Android → per-platform cinterop/JNI (MPNowPlayingInfoCenter on Apple, MPRIS on Linux, SMTC on Windows, browser MediaSession API on Web)
- M3U parser → `:provider:m3u`
- Xtream API client → `:provider:xtream`
- Stalker portal client → `:provider:stalker`
- XMLTV streaming parser → `:core:epg` (on top of Okio, which is transitive via SQLDelight/Ktor)

**What stays in the catalog** (passed the audit): Kotlin, Gradle, AGP, Compose Multiplatform, kotlinx.* family, androidx.* family (platform-specific by purpose), SQLDelight, Ktor, Media3 (Android platform lib by purpose), Koin (DI), Coil 3 (image), Kermit (logging), Turbine (test), Kotest (test).

**Why:** the project has a 6-platform parity requirement and a restoration-heavy architecture. Bus-factor-1 dependencies on load-bearing subsystems are an unacceptable risk. Writing our own for these specific subsystems is tractable (the LOC budgets are documented in R1/R3/R4) and we end up with code we fully own, test, and understand.

**How to apply:** whenever a new dependency is proposed, apply both gates — (a) is it actively maintained by more than one person or one org with a history of continuity? (b) does it handle all six V1 targets gracefully, not "mostly" or "with workarounds"? If either answer is no, hand-roll instead.

**Affected:** `gradle/libs.versions.toml` (dropped entries); [open-questions.md](open-questions.md) R1/R3/R5/R6 (hand-roll architecture sketches).

---

## Remaining open items after this round

- **R2** — Desktop playback backend selection (libVLC vs mpv vs FFmpeg). The only "which library do we bind into" question still open. Tracked in [open-questions.md](open-questions.md).

Everything else (navigation, player abstraction, media session, provider clients, XMLTV parsing) is now a hand-roll implementation task, not a research task.
