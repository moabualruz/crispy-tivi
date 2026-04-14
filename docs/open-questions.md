# Open Questions — Phase-1 Architecture Sketches

All 15 interview questions and the dependency audit are resolved in [decisions.md](decisions.md). After D17 (hand-roll policy) and D18/D19 (desktop backend pinned to libmpv + bytedeco ffmpeg), **zero library-adoption research tasks remain**. Everything in this file is now architecture-sketch territory — handed-down design notes for phase-1 implementation work, not open questions.

What remains:

- Architectural decisions that need written-down architecture for the phase-1 implementers (R1, R3, R5, R6)
- Hand-roll heads-ups so nobody hunts for a library that doesn't exist (R4)
- R2 kept as a historical record of the backend comparison that produced D18

All items ship **within V1** per [v1-phase-roadmap.md](v1-phase-roadmap.md). Nothing here is post-V1.

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

## R2 — Desktop playback backend: RESOLVED → libmpv via custom JNA binding ([decisions.md](decisions.md) D18)

**Status:** **RESOLVED.** Desktop backend = **libmpv** (LGPL v2.1+ build) via a hand-rolled JNA binding in `:platform:player:desktop`. Thumbnail extraction + stream probing use a **separate** `javacpp-presets ffmpeg 8.0.1-1.5.13` dependency (LGPL v3 build) in `:core:image` and `:core:playback` — see D19.

**Candidates evaluated and dropped:**

| Candidate | Verdict |
|---|---|
| **libVLC via vlcj** | **License-blocked.** vlcj is GPL v3 and requires a paid commercial license from Caprica Software to ship proprietary. Also the largest bundle (~100+ MB plugin tree) and has documented macOS notarization pain across hundreds of plugin dylibs. |
| **GStreamer via gst1-java-core** | LGPL-safe with the strongest LL-HLS / multicast TS pedigree, but ~120 MB plugin tree, macOS/Windows packaging friction (`GST_PLUGIN_PATH` + writable registry cache), no Compose Desktop production users, and — critically — no libplacebo equivalent, so picture quality tuning is far behind MPV. Viable 2nd choice only if libmpv proves problematic during implementation. |
| **FFmpeg via JavaCV (as a player)** | Frame-grabber, not a player. Building a real player on it requires reimplementing A/V sync, audio device output, libass rendering, and adaptive HLS — 3–6 months of custom work that ends in a worse player than mpv's. Wrong abstraction layer for playback. (FFmpeg via javacpp-presets directly is still used for thumbnails — see D19.) |
| **JavaFX MediaPlayer** | Eliminated immediately: worst codec coverage, can't reliably handle live IPTV. |

**Why libmpv won:**

1. **License:** LGPL v2.1+ when built in LGPL mode. Commercial-proprietary safe via dynamic linking.
2. **Picture quality (the priority stated in the decision):** libmpv uses **libplacebo** for HDR tone mapping (BT.2390, BT.2446a, dynamic per-scene), debanding, film grain synthesis, ICC display profiles, and high-quality polar resamplers (ewa_lanczossharp, spline36). No other candidate matches this.
3. **Enhancement filter ecosystem (the priority stated in the decision):** MPV's GLSL shader system is the largest desktop library of drop-in video enhancement shaders — Anime4K, RealCUGAN/RealESRGAN, NVIDIA Image Scaling, AMD FSR 1.0, KrigBilateral, SSimDownscaler, SSimSuperRes — all distributable as `.glsl` files and loadable at runtime with a single `change-list glsl-shaders append <path>` command. Users can stack multiple shaders and toggle them mid-playback. GStreamer's filter graph cannot match this.
4. **Bundle size:** ~25–35 MB per OS, one library, no plugin tree.
5. **Render path:** `mpv_render_context` with `MPV_RENDER_API_OPENGL` shares a GL texture with Skiko's `DirectContext` directly. The only direct-GPU render path of the four candidates.
6. **Institutional native maintenance:** mpv project active since 2012, libmpv is battle-tested, bus factor not a concern for the native library.

**What gets built in phase 1:**

- JNA binding (`net.java.dev.jna:jna 5.18.1` + `jna-platform`) in `:platform:player:desktop` over `mpv_create`, `mpv_set_option_string`, `mpv_command_async`, `mpv_observe_property`, `mpv_event_queue`, `mpv_render_context_create`, `mpv_render_context_render`, `mpv_render_context_free`. ~1–2 KLOC of Kotlin.
- `mpv_render_context` OpenGL integration with Skiko `DirectContext`.
- `PlaybackBackend` contract implementation wrapping mpv's property observation as `StateFlow<PlayerState>` + `Flow<PlayerEvent>`.
- Gradle build-time libmpv binary fetch per target OS into `build/libmpv-cache/` (gitignored) and bundle via `compose.desktop.application.nativeDistributions.appResourcesRootDir`.
- E2E tests: HLS live + MPEG-TS + VOD playback on Linux + Windows runners.

**Reference to cherry-pick from (do not consume as dependency):** animeko's in-progress MPV backend at [open-ani/mediamp](https://github.com/open-ani/mediamp) on the MPV branch.

**Single-maintainer note:** we are the maintainer of the binding. That's the point. libmpv native is institutionally maintained; the thin Kotlin binding is ours to own per D17.

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
- Q14 Desktop playback backend → D14 → **RESOLVED** via D18: libmpv via custom JNA binding. Thumbnails + probe use javacpp-presets ffmpeg (D19). R2 kept above as historical record.
- Q15 Platform tiers → D15 (all six ship V1)
- Dependency audit → D17: drop ill-maintained or single-platform-only libraries and hand-roll
- Feature scheduling → D16: SPEC-RAW §21 reclassified as V1 late-phase (see [v1-phase-roadmap.md](v1-phase-roadmap.md))
- Desktop player backend → D18: libmpv via custom JNA binding
- Desktop thumbnail + stream probe → D19: `org.bytedeco:ffmpeg 8.0.1-1.5.13` LGPL v3 build, consumed directly (no JavaCV)
- Dependency audit → D17: drop ill-maintained or single-platform-only libraries and hand-roll. Drops: Decompose, Voyager, androidx.navigation.compose, MediaMP, kdroidFilter ComposeMediaPlayer, Chaintech, mediasession-kt, xmlutil, saifullah-nurani/XtreamApi
- Feature scheduling → D16: SPEC-RAW §21 "Extensibility Requirements" reclassified from post-V1 to V1 late-phase features. Nothing is post-V1. See [v1-phase-roadmap.md](v1-phase-roadmap.md).
