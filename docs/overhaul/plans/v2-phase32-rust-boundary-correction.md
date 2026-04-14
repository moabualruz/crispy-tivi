# Phase 32: Rust Boundary Correction + Source/Provider Migration + Runtime Hydration Migration + Real-Source In-App Proof

Status: complete
Date: 2026-04-13

## Purpose

The remediation review after Phase 31 exposed a blocker-class architecture
drift:

- Flutter still owns some runtime/business derivation that should be Rust-owned
- Flutter bridge/platform shims remain acceptable only when they are thin
  transport adapters, not logic owners
- shared Rust crates are present, but the active Flutter path still bypasses
  them for several runtime lanes

Phase 32 corrected the boundary, moved source/provider/runtime truth back into
Rust, and proved the corrected real in-app provider-to-player journey before
the final playback/diagnostics and release-readiness phase. Flutter
bridge/platform surfaces remain allowed only when they stay thin and
mechanical. The corrected web build requirement is explicit: the wasm package
must land in `build/web/pkg` via `wasm-pack --target no-modules` or the repo
script `app/flutter/tool/build_web_release_state.sh` so browser smoke can load
`pkg/crispy_ffi.js`. Browser smoke now renders instead of blank, and real-
source app proof reaches real media on the corrected boundary.
DDD/SOLID/LOB/DRY enforcement here means each runtime concern must live behind
one Rust-owned module or snapshot boundary, with Flutter limited to narrow
presentation or platform-shim consumption.

## Own

- record the current Flutter-owned business/runtime drift explicitly
- define the replacement map from Flutter-owned logic to Rust-owned modules and
  FFI outputs
- split the remediation work into disjoint swarm lanes with explicit write
  scopes
- update all governing docs so retained Flutter runtime logic is no longer
  treated as acceptable steady-state architecture
- remove migration-history naming from active code so Rust modules, FFI APIs,
  and Flutter bridge surfaces read as domain code instead of phase code
- move provider catalog truth into Rust
- move configured-provider truth into Rust
- move source setup/auth/import/edit/reconnect controller truth into Rust
- move runtime hydration and mock/demo runtime generation into Rust
- record and execute the real in-app proof requirements for the corrected
  boundary

## Required audit findings

The phase output must explicitly cover:

- source/provider setup drift
- configured-provider persistence and hydration drift
- Home/runtime aggregation drift
- playback metadata/controller drift
- diagnostics derivation drift
- mock/demo provider/runtime ownership drift

## Drift corrected in this phase

- source registry semantics, provider kinds, wizard schemas, and source setup
  controller truth are still authored in Flutter
- configured-provider persistence and runtime hydration policy are still
  authored in Flutter bootstrap/data helpers
- Home aggregation is still stitched together in Flutter
- playback session shaping and diagnostics shaping are still authored in
  Flutter
- mock/demo provider and runtime truth are still authored in Flutter fallback
  builders

## Main boundary corrections landed

- source registry semantics, configured-provider commits, and source setup
  controller truth now resolve through Rust-owned `source_runtime`
- real/default and demo/test source truth now resolve through Rust rather than
  Flutter seeding/fallback
- runtime hydration for Home/Live TV/Media/Search now resolves through Rust-
  owned runtime bundles on the active path
- the largest retained shell-fixture fallback branches were removed from the
  active Rust runtime seam and replaced with provider-derived fallback output
- Flutter presentation now consumes smaller coordinators instead of one mixed
  navigation/source/runtime coordinator

## Completed in this phase so far

- documented the currently observed Flutter-vs-Rust boundary drift so the
  phase no longer over-claims closure on playback/runtime/diagnostics
- aligned the phase docs with the branch state: Flutter still owns the active
  player-session, runtime fallback, and diagnostics shaping surfaces
- recorded the DDD/SOLID/LOB/DRY constraint that these concerns should move to
  small Rust-owned modules and thin Flutter presentation consumers, not remain
  embedded in large mixed-responsibility view-models or fallback builders
- corrected the web runtime packaging path so browser smoke loads the Rust wasm
  package from `build/web/pkg` and renders the app instead of a blank spinner
- moved source setup truth onto the Rust seam and kept Flutter at the
  presentation/coordinator edge
- corrected Rust default/demo source-registry truth so:
  - real/default source registry starts empty and opens first-run onboarding
  - seeded configured providers stay behind explicit demo/test use only
- corrected Rust runtime hydration truth so:
  - real-mode provider failures now surface Rust-owned provider-error or empty
    runtime states
  - explicit demo mode keeps Rust-owned seeded runtime available without
    leaking that fallback into the real path
- removed Flutter-owned demo provider seeding on the active path:
  - demo-mode source registry now comes from the Rust source-setup action seam
    instead of `seedConfiguredProviders` logic in Flutter
- moved diagnostics and runtime-bundle loading onto Rust-owned repositories on
  the active path
- added Rust-side Xtream media hydration that falls back to category-scoped
  real fetches before deterministic scaffold branches
- normalized blank real-provider metadata on the Rust seam so empty titles,
  captions, and hero summaries no longer crash Flutter runtime parsing
- proved the Rust real-source seam against the saved Xtream fixture outside
  tracked files: live, media, and search now hydrate as real rather than
  scaffold on that proof harness
- proved the clean real app path outside tracked files:
  - persisted registry contains only the saved Xtream provider
  - app boot consumes that persisted provider in real mode
  - Live TV and Media routes render real runtime instead of first-run or demo
    placeholders
- tightened verification so the repo now checks the real-path truth instead of
  accepting merely non-empty runtime:
  - the Rust suite now distinguishes explicit demo seed behavior from failed
    real-provider hydration
  - the local Linux real-source boot proof now asserts no demo registry notes,
    no provider-error media/live state, and non-empty provider-backed live,
    media, and search runtime
- restored green verification on:
  - `cargo test -p crispy-ffi --lib`
  - `cargo build -p crispy-ffi --release`
  - `flutter analyze`
  - `flutter test test/features/shell`
  - `timeout 120s flutter test integration_test/main_test.dart -d linux`
  - `flutter build linux`
  - `app/flutter/tool/build_web_release_state.sh`
  - browser-driven smoke on the built web bundle
- removed the biggest remaining shell-fixture fallback branches from the active
  Rust runtime seam:
  - media fallback titles, captions, hero copy, and playback URIs now derive
    from provider truth instead of `The Last Harbor` / `Shadow Signals` style
    fixtures
  - live fallback channel, guide, and stream shaping now derives from provider
    truth instead of display-name heuristics such as `Crispy One`,
    `Weekend Cinema`, or `Travel Archive`
- thinned Flutter presentation further:
  - `ShellViewModel` no longer owns the Live/Media selection
    notify-on-change glue directly
  - that selection transition orchestration now sits behind
    `shell_selection_coordinator.dart`
- split the mixed navigation/source coordinator so Flutter presentation now
  separates:
  - `shell_navigation_coordinator.dart`
  - `shell_source_workflow_coordinator.dart`
  - `shell_command_coordinator.dart` as the thin fan-out seam
- activated the shared Rust `crispy-iptv-tools` crate on the active
  source-runtime path for URL normalization at commit time
- reran the clean real-source proof against the saved Xtream fixture:
  - `live_real=true`
  - `media_real=true`
  - `search_real=true`
- reran the retained app proof on the corrected boundary:
  - persisted registry boot remains real-path, not demo-path
  - Linux release binary launches cleanly against the clean persisted-provider
    config

## Replacement map

- source registry truth -> Rust `source_runtime`
- source setup controller truth -> Rust `source_runtime`
- source setup command orchestration -> Flutter presentation coordinator only
- configured-provider commit logic -> Rust `source_runtime`
- runtime hydration -> Rust `source_runtime`
- demo/mock runtime generation -> Rust `source_runtime`
- playback metadata derivation -> Rust `playback_runtime`
- diagnostics derivation -> Rust `diagnostics_runtime`
- personalization persistence -> Flutter presentation coordinator only
- Flutter presentation surfaces may remain, but only as passive consumers of
  Rust-owned snapshots and controller outputs

## Still open after this phase

- follow-on playback/diagnostics ownership and release-readiness rerun move to
  Phase 35
- `crispy-catchup` and `crispy-xmltv` remain unused in the active crate graph;
  they are not forced into Phase 32 without a justified seam
- provider-derived fallback behavior for unsupported/error lanes still exists
  in Rust by design; it is no longer shell-fixture-driven and is not a Phase
  32 blocker

## Option 3 recheck

Option 3 was rechecked after the Rust-first correction landed.

- residual mixed-responsibility seams:
  - normal presentation/view-model orchestration still exists in Flutter, but
    the business/runtime/provider ownership drift corrected in this phase no
    longer requires a branch-wide rewrite
  - follow-on playback/diagnostics and readiness work remains Phase 35 scope
- whether a larger rewrite is still required:
  - no

## Gate

Phase 32 closed with all of the following satisfied:

- the anti-drift rules are updated in all governing docs
- the remediation track after Phase 31 is rewritten around Rust-boundary
  correction rather than narrow crate activation language
- the swarm execution plan exists with disjoint write scopes
- the next allowed lane is Phase 35
- source/provider migration ownership is folded into this phase
- runtime hydration/mock-demo migration ownership is folded into this phase
- the real in-app proof requirement is folded into this phase
- the option-3 recheck is recorded with an explicit yes/no judgment on whether
  a larger rewrite is still required
- browser build requirements are recorded explicitly, including the
  `build/web/pkg` wasm package path and `pkg/crispy_ffi.js` load path
