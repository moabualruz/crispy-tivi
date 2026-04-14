# Post-Phase-29 Remediation Plan

Status: active
Date: 2026-04-13

## Purpose

Phase 29 closed the first full runtime track as `not ready`. This document
defines the required remediation track that must land before release-readiness
can be judged again.

## Remediation order

### Phase 30: provider persistence and import runtime

Status: complete

Own:

- real provider save/update/delete persistence
- source setup commit through runtime repositories instead of local-only
  controller mutation
- import execution state and error state through retained runtime/controller
  ownership

### Phase 31: provider-driven runtime hydration

Status: complete

Own:

- bootstrap hydration from configured providers
- real Home/Live TV/Media/Search population from imported provider state
- removal of empty-runtime truth as the normal post-setup path

Closure:

- retained real boot now loads persisted personalization plus retained runtime
  templates and hydrates Live TV, Media, and Search from configured-provider
  capability truth
- unsupported lanes stay empty instead of showing unrelated demo/runtime
  shelves
- next allowed lane: Phase 32

### Phase 32: Rust boundary correction + source/provider migration + runtime hydration migration + real-source in-app proof

Status: complete

Own:

- record the current Flutter-owned provider/runtime business logic as
  migration debt
- define the replacement map back to Rust-owned runtime/controller outputs
- lock the swarm execution plan and write scopes before more implementation
- move provider catalog truth into Rust
- move configured-provider truth into Rust
- move source setup/auth/import/edit/reconnect controller truth into Rust
- move Home/Live TV/Media/Search runtime hydration into Rust
- move mock/demo runtime generation into Rust
- remove Flutter-side fallback/runtime shaping from bootstrap/data layers
- prove the real-source in-app provider-to-player journey under the corrected
  Rust boundary
- run a post-integration recheck to decide whether a larger rewrite is still
  required after the Rust-first correction

Closure:

- Flutter bridge/platform shims remain acceptable only as thin adapters, not
  owners of runtime, business, provider, or mock derivation
- the web build requirement is now explicit: `wasm-pack --target no-modules`
  or `app/flutter/tool/build_web_release_state.sh` must place the wasm package
  into `build/web/pkg` so the runtime can load `pkg/crispy_ffi.js`
- browser smoke now renders instead of blank and the rebuilt bundle loads
  `pkg/crispy_ffi.js` correctly, and real-source app proof now reaches real
  media
- Rust default/demo source-registry truth is corrected:
  - real/default starts empty
  - demo/test seeded providers are explicit only
- Rust runtime hydration truth is corrected:
  - failed real providers no longer backfill scaffold/demo runtime
  - explicit demo mode remains available only through Rust-owned seeded seams
- demo-mode seeded providers no longer come from Flutter-owned repository
  seeding; the active demo path now requests seeded registry truth through the
  Rust source-setup seam
- clean persisted Xtream proof now boots the app in real mode with one
  configured provider and renders Live TV and Media from real runtime
- the largest retained shell-fixture fallback branches in Rust runtime
  hydration have been replaced with provider-derived fallback output for both
  media and live/guide surfaces
- `ShellViewModel` no longer owns direct Live/Media selection notify-on-change
  glue, and the mixed navigation/source coordinator is split into smaller
  presentation coordinators
- DDD ownership here now resolves to Rust-owned runtime/controller boundaries
  with Flutter kept at the presentation/shim edge only
- shared `crispy-iptv-tools` is active on the source-runtime commit path for
  URL normalization
- next allowed lane: Phase 35

### Phase 35: playback and diagnostics Rust migration + release-readiness rerun

Status: complete

Own:

- move playback metadata derivation into Rust
- move diagnostics derivation into Rust
- activate shared Rust crates on the active playback/diagnostics path
- rerun Linux/web/build/test/manual readiness evidence after Phases 30 to 35
- explicit final readiness judgment
- blocker ledger refresh if still not ready

Closure:

- playback metadata derivation is now Rust-owned on the active path
- diagnostics derivation is now Rust-owned on the active path
- the saved Xtream real-source proof now passes both in the Rust harness and in
  the Linux in-app boot proof
- Linux release, Linux integration smoke, web rebuild, wasm packaging, and
  browser smoke have all been rerun from the remediated path
- final judgment for this remediation track remains `not ready`
- refreshed blocker ledger is now:
  `docs/overhaul/plans/v2-phase35-release-blockers.md`
- next allowed lane: none inside the current remediation track

## Rule

Do not reopen product-complete or release-ready claims until this remediation
track is executed and closed.

Do not treat the late rewrite recheck as permission to keep mixed ownership in
the active path. The Rust-first correction remains mandatory; the later recheck
exists only to judge whether further rewrite work is still needed afterward.
