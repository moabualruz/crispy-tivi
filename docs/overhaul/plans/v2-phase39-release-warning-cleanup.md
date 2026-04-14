# Phase 39: Rust/FRB Release-Warning Cleanup

Status: complete
Date: 2026-04-14
Outcome: ready

## Purpose

Phase 39 owned the last blocker-class warning debt on the active Rust/FRB path
 and the final release-readiness rerun for the post-Phase-35 cleanup track.

## Changes

- `crispy-ffi` now inherits workspace lints in
  `rust/crates/crispy-ffi/Cargo.toml`, which removes the `frb_expand`
  warning seam from the active crate boundary.
- `crispy-xmltv` now uses target-specific compression dependencies so the web
  wasm package no longer pulls `lzma-sys` into the `wasm32` build path.
- wasm-only Rust warning debt was removed from the active runtime path by
  tightening target ownership around diagnostics/runtime helpers instead of
  suppressing warnings wholesale.

## Verification Evidence

- `cd rust && cargo test -p crispy-ffi --lib`
- `cd rust && cargo build -p crispy-ffi --release`
- `cd rust/shared/crispy-xmltv && cargo test`
- `cd app/flutter && flutter analyze`
- `cd app/flutter && flutter test test/app/app_bootstrap_test.dart test/features/shell`
- `cd app/flutter && timeout 120s flutter test integration_test/main_test.dart -d linux`
- `cd app/flutter && flutter test integration_local/real_source_boot_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `cd app/flutter && flutter build linux`
- `cd app/flutter && app/flutter/tool/build_web_release_state.sh`
- built-web browser smoke on `http://127.0.0.1:8092/`
  - page title: `CrispyTivi`
  - `pkg/crispy_ffi.js` served with `200`
  - `pkg/crispy_ffi_bg.wasm` served with `200`
  - screenshot: `.playwright-cli/phase39-web-smoke.png`
  - Playwright still lands on Flutter's accessibility interstitial in the
    viewport, but the built page and Rust wasm assets load successfully with no
    console errors

## Closure

- blocker-class Rust/FRB warning debt is cleared on the active native and wasm
  release paths
- the real-source readiness rerun remains green on the saved Xtream fixture
- the Phase 35 blocker ledger is now resolved
- there is no next allowed lane inside the current cleanup track
