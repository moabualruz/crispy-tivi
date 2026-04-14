# AGENTS.md

Portable coding-agent guide for this repository. Follows the [AGENTS.md open standard](https://agents.md/) (Linux Foundation, Dec 2025). All agents — Claude Code, Copilot CLI, Codex, Gemini CLI, cursor, etc. — should read this file first.

## Repository state

This is a Kotlin Multiplatform + Compose Multiplatform monorepo for **Crispy-Tivi**, a cross-platform IPTV app targeting Android, iOS, Windows, macOS, Linux, and Web — all six as first-class V1 targets.

The branch `kotlin_try` is currently scaffolding-only: 50 module skeletons, build-logic convention plugins, CI wiring. No feature code yet. All authoritative requirements live under `docs/`.

## Where to start

Read in this order. When any file under `docs/` contradicts another, `docs/decisions.md` wins.

1. **`docs/Requirements.md`** — index + reading order
2. **`docs/decisions.md`** — 17 resolved decisions from the conflict-resolution interview + dependency audit. Authoritative. Key ones to know: D13 (hand-rolled nav), D14 (desktop player backend still open), D15 (all six platforms ship V1), D16 (nothing is post-V1 — SPEC §21 is V1 late-phase), D17 (drop ill-maintained or single-platform-only libraries and hand-roll).
3. **`docs/v1-phase-roadmap.md`** — every V1 feature by phase (foundation → core MVP → late-phase → release polish). Use this to know *when* a feature ships, not whether.
4. **`docs/code-standards.md`** ← emphasized — UDF, DDD-lite, adapter/strategy/facade/policy patterns, StateFlow rules, DRY/SOLID pragmatics, naming, error model, performance rules, testing focus. Every code change must conform.
5. **`docs/monorepo-blueprint.md`** ← emphasized — authoritative module graph, responsibilities, dependency direction, package layout, file shapes, boundary rules, naming rules, merge/split guidance.
6. Supporting requirements: `docs/tech-spec.md`, `docs/platform-behavior.md`, `docs/data-model.md`, `docs/db-schema-guide.md`, `docs/contract-api-spec.md`, `docs/architecture-decisions.md`, `docs/uiux-spec.md`.
7. `docs/orchestrator-start-prompt.md` / `docs/orchestrator-short-prompt.md` — research → brainstorm → plan → execute → verify workflow for non-trivial work.
8. `docs/open-questions.md` — hand-roll architecture sketches for navigation (R1), player backend (R3), media session (R5), casting (R6), plus the single remaining research task R2 (desktop playback backend: libVLC vs mpv vs FFmpeg).

## Repository layout

Module grouping follows the Now-in-Android canonical pattern:

```
crispy-tivi/
├── app/{android,ios,desktop,web}
├── build-logic/                 # Gradle convention plugins
├── core/{design-system,navigation,playback,epg,image,security,export-import}
├── data/{contracts,repositories,normalization,search,sync,restoration,observability}
├── docs/                        # requirements, decisions, roadmap, ADRs
├── domain/{model,services,policies}
├── feature/{home,live,guide,movies,series,search,library,sources,settings,player,onboarding}
├── gradle/                      # wrapper + libs.versions.toml
├── platform/
│   ├── player/{android,apple,desktop,web}
│   ├── security/{android,apple,desktop,web}
│   └── observability/{android,apple,desktop,web}
├── provider/{contracts,m3u,xtream,stalker}
└── test/{fixtures,contracts}
```

Gradle paths use `:` separators: `:core:navigation`, `:feature:live`, `:platform:player:apple`.

## Build commands

```bash
./gradlew projects                         # list the module tree
./gradlew build                             # full project build
./gradlew :app:android:assembleDebug        # Android debug APK
./gradlew :domain:model:compileKotlinJvm    # compile a single shared module
```

Requires JDK 21 on PATH. Android SDK is required for `:app:android`; path goes in the gitignored `local.properties` file (`sdk.dir=/path/to/android-sdk`).

CI is **manual-trigger only** — `.github/workflows/build.yml` runs via workflow_dispatch. Nothing is auto-triggered on push/PR.

## Dependency policy (D17)

If a dependency is ill-maintained (single-maintainer on a load-bearing subsystem, stale releases, pre-1.0 with no roadmap) **or** does not handle all six V1 targets gracefully, drop it and hand-roll.

**Dropped so far:** Decompose, Voyager, androidx.navigation.compose (navigation); MediaMP / kdroidFilter ComposeMediaPlayer / Chaintech (player wrappers); mediasession-kt (desktop media session); xmlutil (XMLTV); saifullah-nurani/XtreamApi.

**Kept:** Kotlin 2.3.20, Gradle 9.4.1, AGP 9.1.0, Compose Multiplatform 1.10.3, kotlinx.* family, androidx.* family, SQLDelight 2.3.2, Ktor 3.4.2, Media3 1.10.0 (Android), Coil 3.4.0, Koin 4.2.1, Kermit 2.1.0, Turbine 1.2.1, Kotest 6.1.11.

**Hand-rolled subsystems:** navigation + back stack + restoration (`core/navigation` + `data/restoration`), `PlaybackBackend` contract + per-platform impls (`core/playback` + `platform/player/*`), media session on non-Android (`platform/player/*` via cinterop/JNI), M3U / Xtream / Stalker parsers (`provider/*`), XMLTV streaming parser (`core/epg`), casting contract + per-platform impls (phase 3).

Apply both gates before adding any new dependency to `gradle/libs.versions.toml`.

## V1 scope (D16)

Nothing is post-V1. The V1 feature set is complete and divided into four phases in `docs/v1-phase-roadmap.md`:

- **Phase 1** — foundation (convention plugins, shared architecture, playback contract, design tokens, persistence, observability)
- **Phase 2** — core MVP (onboarding, source management, live/movies/series/guide/search/library, sync, EPG, search, playback, media session, image pipeline, restoration, import/export, diagnostics)
- **Phase 3** — late-phase features (subtitles, audio tracks, PiP, background playback refinement, catch-up/archive, recording, parental controls, **casting** — Google Cast + AirPlay + DLNA — richer provider capabilities, multi-profile, TV/tablet refinement)
- **Phase 4** — release polish (cross-platform parity audit, performance tuning, accessibility, diagnostic finalization, release artifacts, documentation)

SPEC-RAW §21 "Extensibility Requirements" is reclassified as V1 Phase 3. If a feature cannot fit in V1, it must be explicitly added to the roadmap with rationale — there is no invisible V2 backlog.

## Non-negotiable invariants

- **No provider-specific logic in UI-facing flows.** M3U/Xtream/Stalker payloads are normalized by `data/normalization` + `provider/*` before reaching features.
- **Source identity is preserved end-to-end.** UI may render aggregate views, but underlying source variants and attribution are always recoverable.
- **Feature modules depend on contracts, not platform implementations.** `platform/player/*`, `platform/security/*`, `platform/observability/*` implement shared contracts and are wired only by `app/*` modules.
- **No hard-coded design values in features.** Design-system tokens and components only. The token taxonomy is being designed fresh from `docs/uiux-spec.md` §5 — do not revive the deprecated Flutter-era tokens.
- **Large surfaces must be virtualized/windowed.** No eager full-list transformations, no parsing/ranking/decoding on the main thread, no uncancellable off-screen work.
- **Restoration is a first-class subsystem.** Minimal state in platform save containers; durable restoration comes from the local DB via `data/restoration` and `RestorationRecord`.
- **Secrets never in plaintext in the main DB.** `core/security` `SecretStore` contract, native per-platform backends in `platform/security/*`.
- **Terminology:** `Library` = personal return points (Continue Watching, Favorites, History, Saved positions, Recently Played Channels). VOD browsing lives in `feature/movies` and `feature/series` and is called "catalog", not "library".

## Workflow reminder

For any non-trivial change, follow the orchestrator workflow (`docs/orchestrator-start-prompt.md`): research first, brainstorm, shrink uncertainty, plan, execute, verify. Do not skip research. Do not ask the user piecemeal questions — bundle any real gray areas into one decision packet.
