# Phase 38: Shared XMLTV And Catchup Activation

Status: complete
Date: 2026-04-14

## Purpose

Activate the last two shared Rust crates that were still outside the active
runtime path after Phase 35:

- `crispy-xmltv`
- `crispy-catchup`

## Completed In This Phase

- activated `crispy-xmltv` in the active `crispy-ffi` crate graph
- wired XMLTV parsing into the retained M3U live-runtime path in Rust
- XMLTV guide-source precedence is now provider-type aware:
  - `M3U URL`: `xmltv_url`, then `xmltv_file`
  - `local M3U`: `xmltv_file`, then `xmltv_url`
- XMLTV hydration falls back deterministically to the retained Rust guide
  scaffold when guide input is missing or invalid
- activated `crispy-catchup` in the active `crispy-ffi` crate graph
- wired archive/timeshift playback derivation into the live playback source
  options on the Rust-owned path
- kept Flutter thin; no new Flutter business/runtime logic was introduced

## Verification Evidence

- `cargo test -p crispy-ffi local_m3u_live_runtime`
- `cargo test -p crispy-ffi m3u_url_live_runtime_hydrates_guide_from_xmltv_url`
- `cargo test -p crispy-ffi --lib`
- `cargo build -p crispy-ffi --release`
- `flutter analyze`
- `flutter test test/features/shell/playback_backend_test.dart test/features/shell/player_session_test.dart test/features/shell/player_view_test.dart test/features/shell/diagnostics_runtime_test.dart`

## Closure

- the active crate graph now includes `crispy-xmltv` and `crispy-catchup`
- the old unused-patch blocker for those shared crates is cleared
- next allowed lane: Phase 39
