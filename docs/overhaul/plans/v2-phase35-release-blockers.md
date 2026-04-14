# Phase 35 Release Blockers

Status: resolved
Date: 2026-04-14
Outcome: ready

## Resolved Since Phase 29

- source setup no longer ends at local-only Flutter controller mutation
- real boot no longer drops back to empty runtime after provider persistence
- real-source in-app proof now exists and passes on the saved Xtream fixture
- playback metadata and diagnostics derivation now come from Rust-owned seams on
  the active path

## Final Resolution

- the `flutter_rust_bridge` warning seam was removed by making `crispy-ffi`
  inherit workspace lints from `rust/crates/crispy-ffi/Cargo.toml`
- shared `crispy-xmltv` now stays wasm-safe on the active web packaging path,
  so the web Rust package no longer fails through `lzma-sys`
- the final readiness rerun is recorded in
  `docs/overhaul/plans/v2-phase39-release-warning-cleanup.md`

## Resolved In Phase 38

- `crispy-xmltv` is now active on the retained M3U live-runtime guide path
- `crispy-catchup` is now active on the retained live playback source-option
  path
- the unused shared-crate blocker is closed in
  `docs/overhaul/plans/v2-phase38-shared-xmltv-catchup-activation.md`

## Next Step Requirement

- no next allowed lane remains inside this cleanup track
- any further work must start from a newly documented track, not by reopening
  this resolved blocker ledger implicitly
