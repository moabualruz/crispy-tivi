# Phase 35: Playback And Diagnostics Rust Migration + Release-Readiness Rerun

Status: complete
Date: 2026-04-14
Outcome: not ready

## Own

- move playback metadata derivation into Rust
- move diagnostics derivation into Rust
- activate shared Rust crates on the active playback/diagnostics path
- leave Flutter with presentation-side playback/view-state only
- rerun Linux/web/build/test/manual readiness evidence after the remediation
  track
- produce explicit ready / not-ready judgment

## Completed In This Phase

- moved the retained playback metadata seam behind Rust-owned derivation on the
  active path:
  - selected live playback stream now comes from Rust runtime selection truth
  - session snapshot/chooser resolution stays behind the retained playback
    session runtime repository seam instead of widget-local inference
- moved retained diagnostics derivation behind Rust-owned runtime truth:
  - the active diagnostics JSON path now derives from the Rust runtime bundle
  - host-tooling status is taken from the Rust diagnostics seam on the real path
- kept Flutter at the presentation edge by thinning the remaining playback
  consumption path through:
  - `player_playback_controller.dart`
  - `shell_player_coordinator.dart`
  - `shell_player_runtime_coordinator.dart`
  - `playback_session_runtime.dart`
- reran real-source proof against the saved Xtream fixture:
  - Rust harness writes persisted provider state and reports:
    - `live_real=true`
    - `media_real=true`
    - `search_real=true`
  - in-app Linux real-source boot proof passes with one persisted configured
    provider (`look4k`) and populated Live TV / Media on startup
- reran Linux/web/build/test readiness evidence after the full remediation track

## Verification Evidence

- `cargo test -p crispy-ffi --lib`
- `cargo build -p crispy-ffi --release`
- `flutter analyze`
- `flutter test test/app/app_bootstrap_test.dart test/features/shell`
- `timeout 120s flutter test integration_test/main_test.dart -d linux`
- `flutter test integration_local/real_source_boot_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `app/flutter/tool/build_web_release_state.sh`
- browser-driven web smoke on the rebuilt web bundle:
  - `.playwright-cli/phase35-web-smoke.png`

## Judgment

Release readiness: not ready

The remediation track now proves:

- playback metadata derivation is Rust-owned on the active seam
- diagnostics derivation is Rust-owned on the active seam
- real persisted-provider boot works in-app for the saved Xtream source
- Linux and web bundles both rebuild successfully, including the wasm package
  under `build/web/pkg`

The app is still not release-ready because:

- `crispy-xmltv` and `crispy-catchup` are still unused in the active crate
  graph, so shared-crate EPG/catchup ownership is not fully active yet
- release builds still emit Rust/FRB warning debt that should be cleaned before
  a production-ready judgment

The refreshed blocker ledger is recorded in
`docs/overhaul/plans/v2-phase35-release-blockers.md`.
