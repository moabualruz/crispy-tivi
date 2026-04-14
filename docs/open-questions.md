# Open Questions — Phase-1 Research & Architecture Tasks

The 15 interview questions from the suggestive-context conflict review are resolved in [decisions.md](decisions.md). After the April 2026 dependency audit (D17 — hand-roll policy), most subsystem "library adoption" questions collapsed into "hand-roll" decisions. What remains in this file are:

- Architectural decisions that need written-down architecture (R1, R3, R5, R6)
- One genuine backend research task (R2 — desktop playback backend)
- Hand-roll heads-ups so nobody hunts for a library that doesn't exist (R4)

All remaining items ship **within V1** per [v1-phase-roadmap.md](v1-phase-roadmap.md). Nothing here is post-V1.

---

## R1 — Navigation + state pattern (HAND-ROLLED)

**Status:** Architecture committed — we own it. No spike, no framework adoption.

**Why hand-roll:** Decompose is single-maintainer (bus-factor 1 on a load-bearing subsystem), Voyager's last stable is 1.0.1 (active work is in 1.1.0-beta), and androidx-navigation-compose is KMP-stable only on Android. Navigation is deeply entangled with restoration, which is a core V1 subsystem, so external bus-factor risk is unacceptable. D17 says drop + build our own.

**Module home:** `:core:navigation`.

**Architecture sketch (to be elaborated in the navigation-core README before implementation):**

- **Typed destinations.** Sealed-class `AppDestination` hierarchy per the CONTRACT-API-SPEC §15.1. Each feature contributes its own destinations as a subclass.
- **Back stack.** `BackStack` = `StateFlow<List<AppDestination>>`. Push/pop/replace are pure state operations. No ambient state — the stack is owned by a single root state holder.
- **Navigator.** `Navigator` interface per CONTRACT-API-SPEC §15.2. Implementation is a thin wrapper over `BackStack` that exposes `push`, `pop`, `popTo`, `replace`, `clearTo`.
- **Compose integration.** A single `AppNavHost` composable observes the `BackStack` `StateFlow`, crossfades between destinations, and delegates rendering to per-destination `Screen` composables. No reflection, no classpath tricks.
- **Restoration.** `NavigationRestorationAnchor` (CONTRACT-API-SPEC §15.3) is persisted through the `:data:restoration` module's `RestorationRecorder` on every destination push/pop. Rehydration reconstructs the `BackStack` from the last `RestorationRecord` on app launch, honoring `RestorationPolicy` (CONTRACT-API-SPEC §10.2). Deep restoration (e.g., "return to episode detail in season 3 of series X") stores the full destination parameters, not just the screen name.
- **Survives config change + process death on Android.** The root `BackStack` state holder is hoisted above any `Activity`/`ComponentActivity`, saved to `SavedStateRegistry` via a thin `expect/actual` bridge. On non-Android targets the bridge is a no-op because process death works differently.
- **Remote / gamepad / keyboard.** Directional navigation is a separate concern handled by the focus model inside each `Screen`, not by the back stack. Nothing about the nav pattern blocks remote/gamepad parity.
- **Typed arguments.** Destinations carry value-object parameters, not string params. No URL-encoded path params. Deep links get parsed once at the boundary into a typed `AppDestination`.

**Acceptance criteria (feature work cannot start until all pass):**

- Typed destinations compile cleanly in `:core:navigation` commonMain
- Round-trip restoration works: kill and relaunch the Android app while on feature-series detail view → app returns to that detail view with focus near the previously focused item
- iOS simulator: same restoration works across a full process-death-simulating relaunch
- Desktop: same restoration works across a full app restart on at least Linux
- Web: restoration survives a full page refresh via persisted state
- Remote/gamepad navigation test: D-pad from a rail → panel → back to rail; focus restores to previously focused item
- Unit tests cover BackStack push/pop/popTo/replace/clearTo and every RestorationRecord round-trip

**Exit criterion:** All of the above. Once `:core:navigation` is built, D13 is marked resolved.

---

## R2 — Desktop playback backend (OPEN — real backend choice)

**Status:** Unpinned. Phase-1 research task. The only remaining "which third-party thing do we pick" question.

**What is unresolved:** which native library `:platform:player:desktop` binds into to decode/render IPTV streams on Windows, Linux, and (if we don't route macOS through `:platform:player:apple`) macOS.

Note: this is a **library/backend choice**, not a wrapper choice. KMP player wrappers (MediaMP / kdroidFilter / Chaintech) were evaluated and dropped in R3 per D17. So this question is: what native C library are we JNI-binding?

**Candidates to evaluate in the spike:**
- **libVLC via vlcj** — mature, broadest codec support, IPTV-friendly. License: LGPL. Distribution: vlcj wraps libVLC; users need libVLC installed (or we bundle it per-OS).
- **mpv via libmpv** — very capable, strong HLS/TS support, smaller footprint than VLC. License: GPL-2.0+/LGPL-2.1+. Distribution: libmpv install per-OS; bundling possible.
- **FFmpeg via JavaCV or direct JNI** — most control, widest format coverage, most code. License: LGPL (commercial-safe with the LGPL build). We write the render loop ourselves.
- **JavaFX MediaPlayer** — fewest dependencies but worst codec coverage; does not handle live IPTV reliably. Probably eliminated early in the spike.

**Acceptance criteria the spike must verify:**
- HLS live (TS-over-HLS, fMP4-over-HLS, low-latency HLS)
- Direct MPEG-TS (UDP or HTTP-TS — common on IPTV)
- VOD (MP4, MKV, HLS VOD)
- Subtitle tracks: select, style, delay offset
- Audio track selection
- Playback state observation via `StateFlow<PlayerState>`
- Error propagation as typed `PlayerEvent` failures
- Fullscreen, PiP (where OS supports), seek accuracy
- Cross-platform parity on Windows + Linux (macOS optional per D10 — depends on whether we route macOS through apple)
- Packaging: end-user on a fresh OS install should be able to run the app without separate library installs (bundle libVLC/libmpv/ffmpeg with the distribution)
- License compatibility for commercial IPTV use — LGPL is acceptable if we allow dynamic linking + source availability

**Exit criteria:** one backend chosen, `:platform:player:desktop` stub replaced with a working implementation on at least Windows + Linux, E2E live + VOD tests passing. SPEC-RAW §23.1 and Amendment B marked resolved. ARD ADR-007's desktop bullet updated to name the chosen backend.

---

## R3 — KMP PlaybackBackend contract (HAND-ROLLED)

**Status:** Architecture committed — no third-party wrapper.

**Why hand-roll:** all three KMP player wrappers (MediaMP, kdroidFilter ComposeMediaPlayer, Chaintech) are pre-1.0 single-maintainer, and playback is the most critical V1 subsystem. D17 says drop + build our own.

**Module home:** `:core:playback` (shared contract) + `:platform:player:android`, `:platform:player:apple`, `:platform:player:desktop`, `:platform:player:web` (per-platform impls).

**Architecture sketch:**

- **Shared contract** in `:core:playback` — `PlaybackBackend` interface per CONTRACT-API-SPEC §6.1. Methods: `load`, `play`, `pause`, `stop`, `seek`, `release`. Observations: `StateFlow<PlayerState>`, `Flow<PlayerEvent>`, `StateFlow<TrackInfo>`.
- **Resolution layer** — `PlaybackSelectionService` (CONTRACT-API-SPEC §6.3) produces `ResolvedPlaybackSelection` from an aggregate entity + source scope + user override. Shared, pure logic.
- **Orchestration layer** — `PlaybackFacade` (CONTRACT-API-SPEC §6.2) sits above the backend, attaches chosen backend, updates history, restoration, and media session. Shared.
- **Per-platform backend implementations:**
  - `:platform:player:android` → **Media3 / ExoPlayer** (libraries already in catalog: androidx.media3:media3-exoplayer + -hls + -dash + -rtsp + -smoothstreaming + -session + -datasource-okhttp). Wraps ExoPlayer in the shared `PlaybackBackend` contract.
  - `:platform:player:apple` → **AVPlayer** via cinterop. Covers iOS and macOS. Uses AVURLAsset + AVPlayerItem + AVPlayerLayer for display. Native subtitle/track selection through AVFoundation APIs.
  - `:platform:player:desktop` → backend from R2, wrapped in the shared contract. Stub fails fast until R2 resolves.
  - `:platform:player:web` → **hls.js** via Kotlin/JS externals. hls.js version 1.6.15 in catalog. Pairs with the HTML `<video>` element, exposes the same `StateFlow<PlayerState>`.
- **Expect/actual.** The `PlaybackBackend` contract is `interface` (not `expect class`) so platform modules implement it like any interface. Factory comes through `PlaybackBackendFactory` (CONTRACT-API-SPEC §6.4) which has one `actual` per platform.

**Acceptance criteria:** same PlayerState/PlayerEvent model observable on Android + Apple + desktop (per R2) + Web; switching backends never touches feature code.

**Exit criterion:** end-to-end live playback working on Android + Apple + one desktop target + Web, same unit tests passing against all four backends through the shared contract.

---

## R4 — Provider libraries are hand-rolled (heads-up, not a decision)

**Status:** Unchanged from prior round. Hand-rolled per D17.

- **M3U / Extended-M3U parser** — no maintained KMP library. `BjoernPetersen/m3u-parser` is JVM-only. → `:provider:m3u` rolls its own (~150–250 LOC).
- **Xtream Codes API client** — `saifullah-nurani/XtreamApi` 0.1.7 is the only KMP option but pre-1.0, single-maintainer, missing native-desktop + Web targets. → `:provider:xtream` rolls its own against the documented `player_api.php` endpoints (~400–600 LOC).
- **Stalker / Ministra portal client** — no maintained Kotlin/Java library at all. → `:provider:stalker` rolls its own: MAC auth, token refresh, EPG/VOD/series endpoints (~600–1000 LOC).
- **XMLTV parser** — `xmlutil` was dropped in this round. XMLTV is a narrow DTD; a pull parser driven by Okio's `BufferedSource` is tractable. → `:core:epg` rolls its own `<channel>` / `<programme>` handlers and streams into SQLDelight (~300–500 LOC plus the ingestion pipeline). Must be **streaming** — EPG files can be hundreds of MB and cannot be materialized.

If anyone later finds a maintained KMP library that covers all six targets and is multi-maintainer, revisit and update this file.

---

## R5 — Media session / now-playing across all six platforms (HAND-ROLLED)

**Status:** Architecture committed — no third-party wrapper.

**Why hand-roll:** `mediasession-kt` is single-maintainer, missing macOS and web coverage, and the work per-platform is shallow enough that adapting a cross-platform abstraction costs more than writing four thin per-platform bindings.

**Contract home:** `:core:playback` — `MediaSessionController` interface (Adopt existing contract names from CONTRACT-API-SPEC where possible; otherwise add as new contract).

**Per-platform implementations:**

- **Android:** `:platform:player:android` uses `androidx.media3:media3-session` (already in catalog at 1.10.0). Wraps `MediaSession` + `MediaNotificationManager`. Publishes now-playing metadata, handles media key events and remote commands. Works on phones, tablets, Android TV.
- **Apple (iOS + macOS):** `:platform:player:apple` uses cinterop against `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`. Sets now-playing info dictionary on play/pause/track change, installs remote command handlers for play/pause/skip/seek. Works for lock screen, control center, CarPlay, Apple Watch now-playing, and AirPlay 2 targets.
- **Desktop — Linux:** `:platform:player:desktop` publishes an MPRIS2 D-Bus object via a thin JNI/JNA binding (roll our own over `org.freedesktop.MediaPlayer2` and `org.freedesktop.MediaPlayer2.Player` interfaces). Handles media keys and multimedia keyboard buttons.
- **Desktop — Windows:** `:platform:player:desktop` publishes a `SystemMediaTransportControls` session via WinRT interop. Handles media keys and Game Bar / volume overlay integration.
- **Desktop — macOS:** routed through `:platform:player:apple` (same MPNowPlayingInfoCenter path as iOS).
- **Web:** `:platform:player:web` uses the browser-native `navigator.mediaSession` API via Kotlin/JS externals. Sets metadata, registers action handlers (play/pause/seekTo/skip). Works in Chrome, Edge, Safari, Firefox.

**Exit criterion:** now-playing metadata + hardware media key handling working on Android + iOS + one desktop target + Web, tested manually.

---

## R6 — Casting architecture: Google Cast, AirPlay, DLNA (V1 LATE PHASE — HAND-ROLLED AT THE INTEGRATION LAYER)

**Status:** Architecture scoped. Scheduled for V1 late phase per [v1-phase-roadmap.md](v1-phase-roadmap.md) Phase 3. NOT post-V1.

**Scope:** casting senders for all six platforms. Receivers are out of scope (Chromecast receivers are Google-owned; AirPlay receivers need Apple MFi program; we use existing devices, not build new ones).

**Protocols per target device family:**

- **Google Cast (Chromecast, Android TV, Google TV, Google Home speakers):** proprietary protocol. SDK available only for Android (Google Cast Sender SDK), iOS, Chrome web, and Chromecast receivers. For Windows/macOS/Linux desktop the only practical option is open-source Chromecast libraries (pychromecast-equivalent for JVM, or direct protocol via protobuf).
- **Apple AirPlay (Apple TV, HomePod, AirPlay-capable speakers):** proprietary protocol (AirPlay 2). Free on iOS/macOS via AVPlayer's `allowsExternalPlayback`. On non-Apple platforms, only open-source AirPlay-compatible libraries exist; they're all reverse-engineered and bus-factor 1.
- **DLNA / UPnP (broad, older consumer gear):** open protocol, broadly supported. A reasonable fallback for desktop/Linux/web where Cast/AirPlay are locked down.
- **Miracast:** screen-mirroring, not media casting. Out of scope for IPTV.

**Module plan (added to monorepo at phase-3 start, not now):**

- `cast-core` — shared contract `CastController` with `Flow<List<CastDevice>>`, `connect(device)`, `loadSelection(ResolvedPlaybackSelection)`, `seek`, `play/pause/stop`, `disconnect`. Typed `CastDevice` describes the protocol (GOOGLE_CAST / AIRPLAY / DLNA) and device metadata.
- `platform-cast-android` — Google Cast Sender SDK (`com.google.android.gms:play-services-cast-framework`) + `androidx.mediarouter:mediarouter`. Implements the contract for Chromecast. Requires Google Play Services on the device; behavior degrades gracefully if GMS is missing (the device picker just doesn't show Google Cast devices).
- `platform-cast-apple` — native AirPlay via AVPlayer's `allowsExternalPlayback` = `true` + `AVRoutePickerView` for the picker UI. Essentially free on iOS and macOS. We thin-wrap it behind `CastController`.
- `platform-cast-desktop` — two sub-backends, both hand-rolled:
  - **Google Cast sub-backend:** implement the Cast protocol directly over TLS + protobuf (the Cast protocol is documented via community reverse-engineering). Discovery via mDNS (`_googlecast._tcp.local.`) using a small JVM mDNS library or raw multicast DNS.
  - **DLNA sub-backend:** UPnP SSDP discovery + SOAP over HTTP. Mature, simple. Adds DLNA-only devices (smart TVs, legacy media renderers) for users who don't have Chromecast/AirPlay gear.
  - No Apple AirPlay sender on desktop — reverse-engineered AirPlay libraries are all single-maintainer and Apple actively breaks them. Document this as a V1 gap and point affected users at browser-based Chromecast via `platform-cast-web`.
- `platform-cast-web` — browser-native `RemotePlayback` API (Chromium-based browsers only) as the Cast path; Safari's native AirPlay is usually picked up by the browser transparently. No library needed.

**New Gradle modules to add in phase 3** (currently not in settings.gradle.kts):

```
:cast-core
:platform-cast-android
:platform-cast-apple
:platform-cast-desktop
:platform-cast-web
```

**Dependencies to add to the catalog in phase 3** (currently absent on purpose):

| Purpose | GroupId:ArtifactId | Platform |
|---|---|---|
| Google Cast Sender SDK | `com.google.android.gms:play-services-cast-framework` | Android only |
| MediaRouter for Cast device picker | `androidx.mediarouter:mediarouter` | Android only |
| mDNS discovery (JVM) | `org.jmdns:jmdns` or similar | Desktop only |
| No additional library for AirPlay on Apple | (uses AVFoundation) | Apple only |
| No additional library for DLNA | (hand-roll the small SSDP + SOAP subset we need) | Desktop only |

**Exit criteria for the casting slice:**

- Android app can discover and load a remote playback selection on a Chromecast (live channel + VOD movie)
- iOS app can AirPlay playback to an Apple TV (live channel + VOD movie)
- Desktop (Linux or Windows) can discover and push a live channel to both a Chromecast and a DLNA renderer
- Web app can use Remote Playback API in Chrome to cast to a Chromecast
- `CastController` state is consumed identically across features, so nothing above the contract knows what protocol is in use
- Documented gaps: no AirPlay sender from desktop (users cast to AirPlay from iOS/macOS or use DLNA instead)

**V1 late-phase timing:** casting ships before V1 release but after the core playback path is stable on all platforms. No part of casting blocks Phase-2 MVP features.

---

## Related still-open items (not blocking)

- **SPEC-RAW §23.3 Kotlin media implementation research** — folded into R2 + R3.
- **Design token values** — taxonomy designed fresh from UIUX §5 per D8. Token values (color hexes, spacing ramps, radius ramps, motion timings) tracked separately during design-system phase.

---

## Resolved items (for the record)

The following were resolved in the interview and earlier rounds. See [decisions.md](decisions.md) for the full rationale.

- Q1 Module layout → D1 (REPO-BLUEPRINT fine split)
- Q2 Feature modules → D2 (11 feature modules)
- Q3 "Library" meaning → D3 (personal destination; VOD renamed to "catalog")
- Q4 Live feature name → D4 (`:feature:live`)
- Q5 EPG/guide feature name → D5 (`:feature:guide`)
- Q6 Provider modules → D6 (split per family)
- Q7 Player backend naming → D7 (`platform-player-*`, shared `apple`, dedicated `web`)
- Q8 Design-try folder → D8 (reference-only, Flutter dead, tokens designed fresh)
- Q9 Web tier → D9 (first-class V1 target)
- Q10 Secure storage → D10 (four `platform-security-*` modules)
- Q11 Autoplay default → D11 (on by default, configurable)
- Q12 Backup format → D12 (ZIP of JSONs; secrets excluded by default, opt-in passphrase-encrypted)
- Q13 Nav/state pattern → D13 **UPGRADED** via R1 + D17: hand-rolled in `:core:navigation`, no framework adopted
- Q14 Desktop playback backend → D14 / R2 (spike open; three candidates: libVLC/vlcj, libmpv, FFmpeg)
- Q15 Platform tiers → D15 (all six ship V1)
- Dependency audit → D17: drop ill-maintained or single-platform-only libraries and hand-roll. Drops: Decompose, Voyager, androidx.navigation.compose, MediaMP, kdroidFilter ComposeMediaPlayer, Chaintech, mediasession-kt, xmlutil, saifullah-nurani/XtreamApi
- Feature scheduling → D16: SPEC-RAW §21 "Extensibility Requirements" reclassified from post-V1 to V1 late-phase features. Nothing is post-V1. See [v1-phase-roadmap.md](v1-phase-roadmap.md).
