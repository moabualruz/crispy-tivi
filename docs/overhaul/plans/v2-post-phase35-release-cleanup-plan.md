# Post-Phase-35 Release Cleanup Plan

Status: complete
Date: 2026-04-14

## Purpose

Phase 35 closed the remediation track as `not ready`. The remaining blockers are
now narrow enough to run as one final cleanup track before another
release-readiness judgment.

## Cleanup order

### Phase 38: shared XMLTV and catchup activation

Status: complete

See:

- `docs/overhaul/plans/v2-phase38-shared-xmltv-catchup-activation.md`

Completion criteria:

- active runtime guide hydration comes from `crispy-xmltv`
- archive/timeshift playback derivation comes from `crispy-catchup`
- Flutter only consumes Rust-owned runtime and playback outputs
- leader-confirmed evidence is recorded before any closure claim

Closure:

- shared XMLTV/catchup activation is verified on the active runtime path
- the phase record now lives in
  `docs/overhaul/plans/v2-phase38-shared-xmltv-catchup-activation.md`
- next allowed lane: Phase 39

### Phase 39: Rust/FRB release-warning cleanup + final release-readiness rerun

Status: complete

See:

- `docs/overhaul/plans/v2-phase39-release-warning-cleanup.md`

Completion criteria:

- workspace-lint inheritance in `rust/crates/crispy-ffi/Cargo.toml` removes the
  FRB warning seam
- blocker-class release warnings are gone on the active Rust/FRB path
- final Linux, web, wasm, browser smoke, and real-source evidence is recorded
  and no blocker-class failures remain
- leader-confirmed evidence is recorded before any closure claim

Closure:

- workspace-lint inheritance in `rust/crates/crispy-ffi/Cargo.toml` removed the
  FRB warning seam on the active crate path
- shared XMLTV wasm packaging no longer pulls `lzma-sys` into the active web
  wasm build path
- final Linux, web, wasm, browser smoke, and real-source evidence is green
- closure is recorded in
  `docs/overhaul/plans/v2-phase39-release-warning-cleanup.md`
- no next allowed lane remains inside this cleanup track

## Rule

Do not claim release-ready or product-complete until this cleanup track is
executed and closed.
