# CLAUDE.md — AI Agent Context for CrispyTivi

## Project Summary

CrispyTivi is a cross-platform IPTV & media streaming application.
**Architecture:** Flutter UI (Dart) + Rust backend (crispy-core via FFI).
**State:** Riverpod. **Video:** media_kit. **DB:** sqflite (Dart) + rusqlite (Rust).
**Design:** Dark glassmorphism ("Cinematic Utility") — see `.ai/crispy_tivi_design_spec.md`.
**Targets:** Desktop, Android (phone/tablet/TV), iOS, Samsung Tizen, WebOS, Browser.
**Requirements:** 1,329 across 29 categories — see `.ai/planning/REQUIREMENTS.md`.

## Rust Core (crispy-core) — MANDATORY

The `rust/crates/crispy-core/` crate owns ALL business logic, parsing, DB, crypto,
and sync. Flutter calls it via `rust/crates/crispy-ffi/` (dart:ffi bridge).

### Rust Conventions
- **Edition:** 2024. **Naming:** `snake_case` functions/vars, `PascalCase` types
- **Error handling:** `thiserror` for library, `anyhow` for binary
- **Pre-commit:** `cd rust && cargo fmt --all && cargo clippy --workspace -- -D warnings`
- **Tests:** `cargo test -p crispy-core` — ≥90% coverage target
- **Security:** AES-256-GCM credential encryption, Argon2id PIN hashing, parameterized SQL only

### Key Rust Modules
| Module | Purpose |
|--------|---------|
| `parsers/` | M3U, Xtream, Stalker, EPG (XMLTV) parsers |
| `services/` | CrispyService (sources, channels, VOD, settings, sync) |
| `database/` | rusqlite + migration runner |
| `algorithms/` | crypto (AES-GCM), pin (Argon2id), url_normalize, cloud_sync |
| `http_resilience.rs` | Retry queue + circuit breaker |

## Design System — "Cinematic Utility" (MANDATORY)

**Source of truth:** `.ai/crispy_tivi_design_spec.md` + `.impeccable.md`
- **Dark-first glassmorphic** — all surfaces use dark glass with subtle borders
- **D-Pad focus = pure white** — every interactive element has stark focus ring
- **Typography:** Outfit (headings), Inter (body/data)
- **Brand accent:** gradient `#FF4B2B → #FF416C` — progress bars and live badges ONLY
- **No skip in onboarding** — mandatory completion
- **See `.ai/planning/USER-JOURNEYS.md`** for 47 user journey specifications

## Git Practices (MANDATORY)

- **Commit messages:** describe changes only — no AI/spec/phase/task references
- **No Co-Authored-By lines** — ever. No AI attribution in git history.
- **Pre-commit:** `dart format`, `flutter analyze`, `cargo fmt`, `cargo clippy` must all pass
- **Never commit:** `.env`, credentials, secrets, `*.local.*` test fixtures

## Platform Targets

See `.ai/docs/project-specs/platform_targets.md` for full matrix.
Flutter covers Desktop + Mobile + Android TV + Samsung Tizen. Apple TV needs Swift shell.

## Lessons Learned (from Rust/Slint branch — apply to Flutter)

- **TvgId is NOT a channel identifier** — use `external_id` + `source_id` as upsert key
- **All parsers MUST create stream endpoints** — channels without URLs are useless
- **Sync fires on startup AND on source add** — per-source mutex prevents duplicates
- **reqwest Client is a connection pool** — build once, reuse everywhere
- **Image HTTP timeouts mandatory** — always set 5s connect + 10s request
- **Session-permanent image failure cache** — failed URLs never retried until restart
- **Images only for viewport** — only request images for visible items
- **Grid virtualization matters** — 10K+ items must use lazy builders (GridView.builder)
- **Slint was abandoned** due to: no grid virtualization, no iOS, no TV focus system

## CRITICAL: Read and Apply ALL Docs First

Before ANY task, you **MUST** read and **APPLY** all requirements from the
`.ai/docs/` directory. These documents are the **source of truth** — code must
match docs, not the other way around.

### Mandatory Documentation (.ai/docs/)

| Doc                                              | Purpose                                       | When to Read                     |
| ------------------------------------------------ | --------------------------------------------- | -------------------------------- |
| `.ai/docs/project-specs/ui_ux_spec.md`           | Feature matrix, screen specs, interactions    | Before ANY feature work          |
| `.ai/docs/project-specs/design_system.md`        | Color tokens, typography, spacing, components | Before ANY UI work               |
| `.ai/docs/project-specs/conversion_plan.md`      | Migration roadmap                             | Before architecture decisions    |
| `.ai/docs/project-specs/ux_workflows.md`         | Navigation flows, user interaction patterns   | Before ANY screen work           |
| `.ai/docs/project-specs/video_upscaling_spec.md` | GPU upscaling & super resolution spec         | Before player/video quality work |

### Rules for ALL Docs

1. **Read ALL docs** before starting any task that touches the area they cover.
2. **Apply ALL requirements** from docs — don't skip or approximate.
3. **Track status** in docs — mark features "In Progress" when starting,
   "✅ Done" when complete.
4. **Update ALL affected docs** after completing work — keep them current.
5. **Never contradict docs** — if code differs from docs, fix the code OR
   update the docs with a documented decision.

### Bidirectional Sync Rule

> **Code → Docs**: When you implement/change a feature, update the relevant
> doc (mark status, note deviations, add new tokens).
>
> **Docs → Code**: When you modify a doc (add feature, change token), update
> the code to match in the same task.
>
> **NEVER** leave code and docs out of sync.

## Style Guide

- **Line length**: Use `dart format` default (don't override).
- **Trailing commas**: Mandatory on all argument lists and collection literals.
- **Imports**: Dart-style (dart:, package:, relative) — sorted alphabetically.
- **Naming**: `camelCase` for variables/functions, `PascalCase` for
  classes/enums, `snake_case` for files.
- **Constants**: Use `static const` or top-level `const`. Never `static final`
  for compile-time values.
- **Comments**: Use `///` doc comments on all public APIs.

## Architecture Layers

```text
Presentation → Application → Domain ← Infrastructure
```

- **Domain**: Pure Dart. Zero Flutter imports. Entities, value objects,
  repository interfaces.
- **Infrastructure (data/)**: Implements domain repos. Uses dio, ObjectBox,
  platform APIs.
- **Application**: Use cases orchestrating domain logic.
- **Presentation**: Riverpod providers + Flutter widgets.

### Key Rule

Domain NEVER depends on infrastructure. All infra access is through abstract
repository interfaces defined in domain.

### Architecture Boundary Rule (MANDATORY)

- **Rust owns ALL business logic, data processing, algorithms, validation,
  and persistence.** Any computation that can run in Rust MUST run in Rust.
  Flutter/Dart must NEVER duplicate logic that exists or should exist in Rust.
- **Flutter/Dart owns ALL UI rendering, animations, transitions, theming,
  navigation, and user interaction.** Rust must NEVER dictate visual layout.
- When adding a feature: ask "Is this logic or presentation?" Logic → Rust.
  Presentation → Dart. If mixed: split at the FFI boundary.
- CacheService is the ONLY Dart-side data access layer. Providers read from
  CacheService, NEVER directly from FFI functions.

## Design Token Usage

```dart
// Colors — ALWAYS from ColorScheme (see .ai/docs/project-specs/design_system.md §1.1)
final color = Theme.of(context).colorScheme.primary;

// Spacing — ALWAYS from CrispySpacing (see .ai/docs/project-specs/design_system.md §1.4)
padding: EdgeInsets.all(CrispySpacing.md),

// Radius — ALWAYS from CrispyRadius (see .ai/docs/project-specs/design_system.md §1.5)
borderRadius: BorderRadius.circular(CrispyRadius.md),

// Animation — ALWAYS from CrispyAnimation (see .ai/docs/project-specs/design_system.md §4)
duration: CrispyAnimation.normal,
curve: CrispyAnimation.enterCurve,

// ❌ NEVER hardcode: Color(0xFF3B82F6), 16.0, Duration(milliseconds: 300)
```

## Versioning Scheme

Current version: **0.1.1** (alpha).

| Phase      | Version Range | Rule                                                      |
| ---------- | ------------- | --------------------------------------------------------- |
| Alpha      | `0.1.X`       | Increment last digit each release (`0.1.1` → `0.1.2` → …) |
| Beta       | `0.2.0`       | Jump to `0.2.0` when entering beta                        |
| Production | `1.0.0`       | First stable release                                      |
| Post-1.0   | semver        | `MAJOR.MINOR.PATCH` per [semver 2.0](https://semver.org/) |

Version must be updated in **all three** locations simultaneously:

- `pubspec.yaml` → `version:` field
- `assets/config/app_config.json` → `appVersion` field
- `CHANGELOG.md` → new `## [X.Y.Z]` entry

## File Locations

| What                       | Where                                                       |
| -------------------------- | ----------------------------------------------------------- |
| **Docs (Source of Truth)** |                                                             |
| Feature spec               | `.ai/docs/project-specs/ui_ux_spec.md`                      |
| Design system              | `.ai/docs/project-specs/design_system.md`                   |
| Migration roadmap          | `.ai/docs/project-specs/conversion_plan.md`                 |
| **Config**                 |                                                             |
| System config              | `assets/config/app_config.json`           |
| Agentic rules              | `antigravity.yaml`                        |
| **Core**                   |                                           |
| Theme tokens               | `lib/core/theme/app_theme.dart`           |
| Breakpoints                | `lib/core/widgets/responsive_layout.dart` |
| Failure types              | `lib/core/failures/failure.dart`          |
| **Features**               |                                           |
| IPTV feature               | `lib/features/iptv/`                      |
| Player feature             | `lib/features/player/`                    |
| Settings                   | `lib/features/settings/`                  |

## Command Shortcuts

```bash
flutter pub get                                            # Install deps
flutter pub run build_runner build --delete-conflicting-outputs  # Codegen
flutter test                                               # Run all tests
flutter test test/config/config_service_test.dart           # Run specific test
flutter analyze                                            # Static analysis
dart format lib/ test/                    # Format code
cd rust && cargo run -p crispy-server --release &          # Run web backend (default 8080)
# cd rust && cargo run -p crispy-server --release -- --port 3030 & # Custom port
flutter run -d chrome --web-port 3000                      # Run web frontend
# flutter run -d chrome --web-port 3000 --dart-define=CRISPY_PORT=3030 # Custom port
flutter run -d windows                                     # Run app (desktop)
```

## Build Commands

```bash
# ── Platform builds ──────────────────────────────────────────
flutter build windows                                      # Windows EXE
flutter build apk --release                                # Android APK
flutter build web --release                                # Web app

# ── Linux on Windows (via WSL Ubuntu) ────────────────────────
# The Windows Flutter SDK has CRLF line endings that break in
# Linux. You MUST use a Linux-native Flutter install inside WSL.
# Prerequisites in WSL: clang, cmake, ninja-build, libgtk-3-dev,
#   pkg-config, libmpv-dev (all apt-installable).
wsl -d Ubuntu -- bash -c \
  'export PATH="$HOME/flutter/bin:$PATH" && \
   cd /mnt/f/work/crispy-tivi && \
   flutter pub get && flutter build linux --release'
# IMPORTANT: After a WSL build, run `flutter pub get` on Windows
# to restore Windows paths in .dart_tool/package_config.json.

# ── macOS / iOS (requires macOS host) ────────────────────────
# flutter build macos
# flutter build ios --no-codesign
```

### Android Target Support

The Android build produces a single universal APK that runs on:

- **Phones** — standard `LAUNCHER` intent filter
- **Tablets** — responsive UI adapts via breakpoints
- **Android TV / Fire TV** — `LEANBACK_LAUNCHER` intent filter,
  `touchscreen required=false`, `leanback required=false`, D-pad focus

### Build Prerequisites

| Platform    | Requirement                                                                                                                 |
| ----------- | --------------------------------------------------------------------------------------------------------------------------- |
| Windows     | Visual Studio Build Tools 2022, NuGet (`nuget sources add -Name "nuget.org" -Source "https://api.nuget.org/v3/index.json"`) |
| Android     | Android SDK 36+ at `C:/Android`, JDK 21, `flutter config --android-sdk C:/Android`                                          |
| Linux (WSL) | Ubuntu WSL2, Linux-native Flutter in `~/flutter`, clang, cmake, ninja-build, libgtk-3-dev, pkg-config, libmpv-dev           |
| Web         | Chrome                                                                                                                      |
| macOS       | Xcode, CocoaPods                                                                                                            |
| iOS         | Xcode, CocoaPods, Apple developer account                                                                                   |

### Android Emulators (Pre-configured AVDs)

Three AVDs are pre-configured for testing all Android form factors.
**JAVA_HOME** must point to JDK 21: `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`

| AVD Name       | Form Factor    | Device Profile | Resolution | DPI | Logical dp | Layout Class | Image                                 |
| -------------- | -------------- | -------------- | ---------- | --- | ---------- | ------------ | ------------------------------------- |
| `CrispyPhone`  | Phone          | Pixel 7        | 1080×2400  | 420 | 411×914    | `compact`    | `google_apis_playstore/x86_64` API 34 |
| `CrispyTablet` | Tablet         | Pixel Tablet   | 2560×1600  | 320 | 1280×800   | `large`      | `google_apis_playstore/x86_64` API 34 |
| `CrispyTV`     | TV (simulated) | tv_1080p       | 1920×1080  | 160 | 1920×1080  | `large`      | `google_apis_playstore/x86_64` API 34 |

**CrispyTV note**: True Google TV ARM64 images cannot run on Windows x86_64
(QEMU limitation). This AVD uses the phone x86_64 image with TV-like hardware
config: 160dpi (so 1920px = 1920dp, hitting `large` layout), D-pad enabled,
landscape orientation. It lacks the Leanback launcher but correctly tests
responsive layout, D-pad navigation, and focus handling.

#### Starting Emulators

```bash
export ANDROID_HOME="/c/Android"
# Start individually (add -no-window for headless)
$ANDROID_HOME/emulator/emulator.exe -avd CrispyPhone -gpu host -port 5554 &
$ANDROID_HOME/emulator/emulator.exe -avd CrispyTablet -gpu host -port 5556 &
$ANDROID_HOME/emulator/emulator.exe -avd CrispyTV    -gpu host -port 5558 &
```

#### Running the App on Emulators

```bash
flutter run -d emulator-5554   # Phone
flutter run -d emulator-5556   # Tablet
flutter run -d emulator-5558   # TV
```

#### Running Integration Tests on Emulators

```bash
# One file at a time per device (same as Windows constraint)
flutter test integration_test/app_test.dart -d emulator-5554
flutter test integration_test/app_test.dart -d emulator-5556
flutter test integration_test/app_test.dart -d emulator-5558
```

#### Edge Cases Per Form Factor

**Phone (`CrispyPhone`)**:

- Bottom nav bar (not side rail) at `compact` width
- Portrait/landscape rotation (`compact` ↔ `medium`)
- Soft keyboard overlap on search/PIN dialogs
- Notch/cutout safe area (Pixel 7 punch-hole)
- Android 14 predictive back gesture

**Tablet (`CrispyTablet`)**:

- Side rail navigation at `large` width (1280dp)
- Portrait rotation drops to `medium` (800dp) — verify layout switch
- Split-screen / multi-window mode (half-width layout)
- Touch + keyboard hybrid input mode switching

**TV (`CrispyTV`)**:

- Full D-pad navigation on every screen (arrow keys + Enter)
- Focus rings visible (`InputModeScope.showFocusIndicators`)
- Side rail navigation at `large` width (1920dp)
- Two-panel layouts: channel list (`ChannelTvLayout`) + EPG
- Screens missing `largeBody`: Home, VOD, Series, Search, DVR, Settings
  (fall back to phone layout — known gap)
- No TV overscan padding (known gap for older TVs)
- Search without soft keyboard (voice/on-screen keyboard)

## UI Verification Protocol (MANDATORY)

> **CRITICAL**: You MUST use Chrome to check and verify ALL UI changes.
> Never skip visual verification — every widget change must be confirmed
> in the running app before marking a task as complete.

1. **Start the dev server** before making UI changes:
   - Run the backend: `cd rust && cargo run -p crispy-server --release &` (supports `--port 3030`)
   - Run the frontend: `flutter run -d chrome --web-port 3000` (supports `--dart-define=CRISPY_PORT=3030`)
2. **After EVERY widget/UI change**, navigate to the relevant screen in
   Chrome and verify the change renders correctly. Do NOT skip this step.
3. **Manual simulation**: Perform clicks/scrolls via the browser to
   ensure state management (Riverpod) updates the UI correctly.
4. **Visual check**: Take a screenshot to verify padding, alignment,
   and theme consistency against `.ai/docs/project-specs/design_system.md`.
5. **Responsive check**: Test at multiple viewport sizes (mobile,
   tablet, desktop) when the change affects layout.
6. **Never mark a UI task as done** without Chrome verification.

## Code Style

- Use `StatelessWidget` or `ConsumerWidget` where possible; only
  use `StatefulWidget` / `ConsumerStatefulWidget` when local
  mutable state is required.
- Follow `flutter_lints` rules (enforced via `flutter analyze`).
- Maintain clean separation between business logic (providers) and
  UI (widgets) — no HTTP calls or DB queries in widget code.
- Prefer composition over inheritance for widget reuse.

## Performance & Memory Management Core Rules

1. **Always Dispose Dart Resources**: Override `dispose()` in `StatefulWidget`s and release `StreamSubscription`s, `Timer`s, `AnimationController`s, and `TextEditingController`s.
2. **Dispose Rust Resources**: When using `flutter_rust_bridge`, manually deallocate Rust FFI handles on the Dart side inside `dispose()` if not auto-managed by Dart GC.
3. **No Strong `BuildContext` References**: Do not store `BuildContext` in long-lived variables or singletons across screen transitions.
4. **Isolates & Zero-Copy**: Offload heavy Rust computations to Dart Isolates. Pass large object buffers using `flutter_rust_bridge` zero-copy capabilities.
5. **Riverpod `autoDispose`**: Ensure Riverpod providers caching large objects use `autoDispose` to clear memory when leaving views.
6. **`media_kit` Lifecycle**: Ensure `hwdec` is correctly configured. Dispose of `VideoPlayerController` instances when navigating away. Limit concurrent active players.

## Pre-Commit Formatting (MANDATORY)

> **CRITICAL**: You MUST run formatters before EVERY commit. CI enforces
> formatting checks — commits that fail `cargo fmt --check` or
> `dart format --set-exit-if-changed` will break the pipeline.

### Commands (run both before every commit)

```bash
# Rust — run from rust/ directory
cd rust && cargo fmt --all

# Dart — run from project root
dart format lib/ test/
```

### Formatting Rules

1. **Always format before committing.** No exceptions. Run BOTH commands.
2. **Never commit unformatted code.** If you write or modify any `.rs`,
   `.dart` file, format it before staging.
3. **Format only — no manual style overrides.** Trust the formatter output.
   Do not manually adjust formatting after running the tool.
4. **Verify after formatting.** Run `cargo fmt --check` (in `rust/`) and
   `dart format --set-exit-if-changed lib/ test/` to
   confirm zero changes remain.

## Before Starting Any Task

1. **Read `.ai/docs/project-specs/ui_ux_spec.md`** — Verify feature exists in matrix, check status.
2. **Read `.ai/docs/project-specs/design_system.md`** — Use existing tokens, don't invent new ones.
3. **Read `.ai/docs/project-specs/conversion_plan.md`** — Understand current roadmap step.
4. **Read `.ai/docs/project-specs/ux_workflows.md`** — Understand navigation flows for the screen.
5. **Check feature status** — Mark "In Progress" if starting work.
6. Check `lib/core/theme/` for existing tokens.
7. Check `lib/core/failures/` for existing error types.
8. Run `flutter test` after every change.

## After Finishing Any Task

1. **Update `.ai/docs/project-specs/ui_ux_spec.md`** — Mark feature status (✅ Done), note any
   deviations from spec.
2. **Update `.ai/docs/project-specs/design_system.md`** — Add any new tokens created.
3. **Update `.ai/docs/project-specs/conversion_plan.md`** — Mark completed roadmap items.
4. **Add implementation notes** — Document key decisions below feature in spec.
5. Run `flutter test` and `flutter analyze` — zero failures, zero issues.
6. **Run formatters** — `cargo fmt --all` (in `rust/`) and
   `dart format lib/ test/` before committing.

## Documentation-First Workflow

> **CRITICAL**: Documentation is the source of truth. Code implements docs,
> not the other way around. **ALWAYS** read docs BEFORE coding and update
> docs AFTER coding.

### Pre-Task Checklist (MANDATORY)

Before writing ANY code:

- [ ] **Read ALL relevant docs** in `.ai/docs/` directory
- [ ] Feature exists in `.ai/docs/project-specs/ui_ux_spec.md` feature matrix
- [ ] UI tokens defined in `.ai/docs/project-specs/design_system.md` (use existing, don't invent)
- [ ] Navigation flow documented in `.ai/docs/project-specs/ux_workflows.md`
- [ ] Roadmap status checked in `.ai/docs/project-specs/conversion_plan.md`
- [ ] Status marked as "In Progress" in ui_ux_spec.md before coding

### Post-Task Checklist (MANDATORY)

After completing ANY code changes:

- [ ] **Update ALL affected docs** — this is the FINAL step
- [ ] Feature status updated to "✅ Done" in `.ai/docs/project-specs/ui_ux_spec.md`
- [ ] Any new tokens added to `.ai/docs/project-specs/design_system.md`
- [ ] Navigation flows updated in `.ai/docs/project-specs/ux_workflows.md` if changed
- [ ] Roadmap progress updated in `.ai/docs/project-specs/conversion_plan.md`
- [ ] Implementation notes added below feature spec
- [ ] Tests pass (`flutter test`)
- [ ] Analysis clean (`flutter analyze`)
- [ ] **Formatters run** (`cargo fmt --all` in `rust/`,
      `dart format lib/ test/`)

### Why This Matters

- Docs track project state — future agents need accurate status
- Docs prevent duplicate work — clearly mark what's done
- Docs guide implementation — specs define what to build
- Docs enable handoff — context persists across sessions

## Testing Rules

- **TDD is mandatory:** RED (failing test) → GREEN (minimal impl) → REFACTOR.
- **Red-Green Discipline:** A failing test is a spec. If test is correct, fix code. Never weaken a correct test.
- Use `mocktail` for mocking — never hand-write mock classes.
- Test file location mirrors source: `lib/config/foo.dart` → `test/config/foo_test.dart`.

### Coverage Targets (MANDATORY)
| Layer | Target |
|-------|--------|
| Rust core (parsers, services, DB) | ≥ 90% line coverage |
| Dart domain/application | ≥ 85% line coverage |
| Dart widgets/screens | Test behavior, not implementation |
| Measure: | `flutter test --coverage` + `cargo tarpaulin -p crispy-core` |

### No-Defer Rule (MANDATORY)
- NEVER mark items as "deferred" or "skipped" — plan properly upfront
- Every spec task MUST be completed or resolved with a technical reason

### Widget Testability Convention

All test-facing widget identification goes through two mechanisms:

1. **`TestKeys` class** (`lib/core/testing/test_keys.dart`) — centralized
   `ValueKey` constants for structural elements (screens, sections, tabs,
   lists). Every screen scaffold has `key: TestKeys.xxxScreen`. Factory
   methods for dynamic keys: `TestKeys.navItem(label)`,
   `TestKeys.channelItem(index)`, `TestKeys.vodItem(id)`, etc.

2. **`semanticLabel`** — for interactive elements (buttons, toggles, cards,
   form inputs). These labels serve both testing AND accessibility. Playwright
   e2e tests consume them as `aria-label` on `flt-semantics` DOM nodes.

**Finder hierarchy in test code** (most reliable → least):
1. `find.byKey(TestKeys.xxx)` — structural elements
2. `find.bySemanticsLabel('...')` — interactive elements with semantic labels
3. `find.byType(Widget)` — generic structural queries
4. `find.text('...')` — last resort, only for content assertions

**Rules:**
- NEVER use inline `ValueKey('...')` strings in `lib/` — always use `TestKeys`
- When adding a new screen: add a `TestKeys.xxxScreen` constant and wire it
- When adding an interactive widget: add a `semanticLabel` parameter
- Robot classes (`integration_test/robots/`) import `TestKeys` — never inline keys

## Test Credentials

Test credentials for integration testing are stored in
`.agent/test_credentials.md`. Always use these when testing Xtream, Live TV,
VOD, Series, or EPG features.

## Plan Files Synchronization

External plan files are stored in agent-specific directories. Keep them in
sync with `.ai/docs/` after completing work.

| Agent       | Plan Directory                                                |
| ----------- | ------------------------------------------------------------- |
| Claude Code | `C:\Users\mkh\.claude\plans\` (or `~/.claude/plans/` on Unix) |
| Gemini      | `.agent/plans/` (project-local)                               |

### Rules

1. **After completing a feature**: Update BOTH the plan file AND `.ai/docs/` files.
2. **Plan files track**: Sprint progress, implementation status, remaining work.
3. **Docs track**: Feature specs, design tokens, gap analysis.
4. **Keep in sync**: If plan says "✅ DONE", docs must say "✅ Done" too.
5. **Reference each other**: Plans should reference doc sections, docs can
   reference active plans.

## Team Orchestration (CrispyTivi)

> Full orchestration protocol is in `~/.claude/rules/team-orchestration.md`.
> This section has **project-specific** additions only.

### Roles

| Role           | File                            | Scope                     |
| -------------- | ------------------------------- | ------------------------- |
| Architect      | `.agent/team/architect.md`      | Domain models, interfaces |
| Data Engineer  | `.agent/team/data-engineer.md`  | DB, repos, APIs           |
| State Engineer | `.agent/team/state-engineer.md` | Providers, notifiers      |
| UI Engineer    | `.agent/team/ui-engineer.md`    | Widgets, screens          |
| QA Engineer    | `.agent/team/qa-engineer.md`    | All tests                 |
| DevOps         | `.agent/team/devops.md`         | Builds, platforms         |
| UX Designer    | `.agent/team/ux-designer.md`    | Design specs, tokens      |
| Doc Sync       | `.agent/team/doc-sync.md`       | Documentation parity      |

### CrispyTivi Phase Map

```text
Phase 1 (parallel):  [Architect] + [UX Designer]
Phase 2 (sequential): [Data Engineer] (needs domain interfaces)
Phase 3 (sequential): [State Engineer] (needs data layer)
Phase 4 (sequential): [UI Engineer] (needs providers)
Phase 5 (parallel):  [QA Engineer] + [Doc Sync] + [DevOps]
```

### Sub-Agent Context Line

Use this in all sub-agent prompts for this project:

```text
Context: CrispyTivi, Flutter/Dart, Clean Arch + Riverpod + Drift.
80 char lines, trailing commas, design tokens from lib/core/theme/.
Drift DB v18. 506+ tests. Analyzer must stay at 0 errors.
```

## Cross-Agent Consistency

Multiple AI agents (Claude, Gemini, Cursor, etc.) may work on this codebase.
All agentic configuration files must produce consistent behavior.

### Agentic Files in This Project

| File                    | Agent         | Purpose                           |
| ----------------------- | ------------- | --------------------------------- |
| `CLAUDE.md`             | Claude Code   | Team Lead + Claude-specific rules |
| `GEMINI.md`             | Google Gemini | Gemini-specific rules and context |
| `.cursorrules`          | Cursor AI     | Cursor-specific rules             |
| `.agent/team/*.md`      | All agents    | Shared role definitions           |
| `.agent/settings.json`  | All agents    | Project configuration             |
| `.agent/workflows/*.md` | All agents    | Shared workflow definitions       |

### Cross-Agent Rules

1. **Maintain parity**: When updating one agentic file, update ALL others with
   equivalent rules (adjusting only for agent-specific syntax/capabilities).
2. **Shared context**: All agents share `.ai/docs/`, `.agent/`, and plan files.
3. **Shared team**: All agents use `.agent/team/*.md` role definitions.
4. **Agent-specific paths**: Only the plan directory differs per agent.
   - Claude: `~/.claude/plans/` (external)
   - Others: `.agent/plans/` (project-local)
5. **Same output**: Given identical tasks, all agents should produce similar
   code structure, follow the same design system, and update the same docs.
6. **Handoff support**: Any agent can pick up work started by another agent
   by reading the shared `.ai/docs/` and plan files.
7. **Team structure**: All agentic files reference the same team roles in
   `.agent/team/`. The orchestration protocol is adapted per tool's syntax.

## E2E Testing & QA Protocol

### Iterative Test-Fix-Retest Workflow

When working on ANY feature or fix, follow this loop:

1. **Run automated tests**: `flutter test` + `flutter analyze`
2. **Run integration tests**: `flutter test integration_test/ -d windows`
3. **Run Playwright**: `cd e2e/playwright && npx playwright test`
4. **Agent manual simulation**: Run tests locally via explicit documentation in `e2e/README.md`, review screenshots,
   check against `.ai/docs/project-specs/design_system.md`
5. **If issue found**: Document in `e2e/reports/issues.md`, fix,
   go to step 1
6. **Repeat** until all tests pass and all screenshots look correct

### Test Commands

| Layer       | Command                                                | What it tests             |
| ----------- | ------------------------------------------------------ | ------------------------- |
| Unit/Widget | `flutter test`                                         | 378+ unit/widget tests    |
| Integration | `flutter test integration_test/<file> -d windows`      | Single flow on Windows    |
| Browser     | `cd e2e/playwright && npx playwright test --workers=1` | 4 viewports × all flows   |
| Visual      | `flutter test test/golden/ --update-goldens`           | Generate baselines        |
| Visual      | `flutter test test/golden/`                            | Pixel regression check    |
| Full matrix | Reference commands in `e2e/README.md`                  | Everything, all platforms |

### Platform-Specific Test Notes

**Windows integration tests**: Must run ONE FILE AT A TIME because
Windows locks the build output (LNK1168 linker error). Run each flow
file individually:

```bash
flutter test integration_test/app_test.dart -d windows
flutter test integration_test/flows/profile_flow_test.dart -d windows
flutter test integration_test/flows/epg_flow_test.dart -d windows
# ... etc (8 files total, 27 tests)
```

**Android Mobile & Android TV Native Integration Tests**:
Flutter's `integration_test` framework seamlessly runs true native E2E validations against Android emulators.

1. Boot the target emulator (e.g., Pixel Phone or Android TV Leanback interface).
2. Look up the device ID via `flutter devices` (e.g., `emulator-5554`).
3. Run the exact same native test architecture:

```bash
flutter test integration_test/app_test.dart -d emulator-5554
```

**Playwright Web Tests**: Playwright testing requires the application to be fully built and served correctly over a strict IPv4 local binding, alongside the Rust backend running.
Before running the E2E suite, execute these steps sequentially:

```bash
# 1. Start the Rust API backend
cd rust
cargo run -p crispy-server --release

# 2. Build the Flutter Web App
cd ..
flutter build web --release

# 3. Serve the web app strictly on IPv4 (Solves ERR_CONNECTION_REFUSED)
npx -y http-server build/web -p 3000 -a 127.0.0.1 -c-1 --cors

# 4. Run the Playwright suite
cd e2e/playwright
npx playwright test --workers=4
```

**Flutter integration tests on Chrome**: NOT supported by the
`integration_test` SDK (only native platforms). Use Playwright for
web E2E testing instead.

### Agent Manual Simulation

Every agent session that touches UI MUST:

1. Build the app/start server:
   - Backend: `cd rust && cargo run -p crispy-server --release &`
   - Web App: `flutter build web --release`
   - Windows App: `flutter run -d windows`
2. Take screenshots of affected screens
3. Review screenshots for visual issues
4. Fix any issues found before marking task complete

### Issue Tracking

When a test or manual review finds a bug:

1. Add entry to `e2e/reports/issues.md`
   (date, screen, description, screenshot)
2. Fix the issue
3. Re-run the full test suite to verify fix
4. Mark resolved in `e2e/reports/issues.md`

### Golden Tests (Visual Regression)

Golden baseline images live in `test/golden/goldens/`.
Screens covered: profile selection, settings, EPG timeline,
channel list, VOD browser, app shell navigation.

**Note**: EPG timeline golden is time-sensitive. Regenerate
baselines with `--update-goldens` before regression runs.

### Cross-Platform Testing

Before any release or milestone:

- Run `bash e2e/scripts/run_all_e2e.sh`
- All layers must PASS on all available platforms
- Document platform-specific issues separately

### Test Infrastructure File Locations

| What                | Where                                 |
| ------------------- | ------------------------------------- |
| Integration tests   | `integration_test/`                   |
| Integration helpers | `integration_test/helpers/`           |
| Test fixtures       | `integration_test/fixtures/`          |
| Playwright tests    | `e2e/playwright/tests/`               |
| Playwright config   | `e2e/playwright/playwright.config.ts` |
| Agent scripts       | `e2e/scripts/`                        |
| Issue tracker       | `e2e/reports/issues.md`               |
| Golden tests        | `test/golden/`                        |
| Golden baselines    | `test/golden/goldens/`                |

### Test Output Artifacts (gitignored, agent-readable)

These paths are excluded from git but agents MUST check them after
running tests to diagnose failures:

| Artifact           | Path                                | How to check                                   |
| ------------------ | ----------------------------------- | ---------------------------------------------- |
| Golden failures    | `test/golden/failures/`             | Read tool (PNG diff images)                    |
| Playwright results | `e2e/playwright/test-results/`      | Read tool (screenshots, traces, error context) |
| Playwright report  | `e2e/playwright/playwright-report/` | `npx playwright show-report`                   |
| E2E screenshots    | `e2e/reports/screenshots/`          | Read tool (timestamped dirs)                   |
| Analysis output    | `analysis.txt`                      | Read tool                                      |
