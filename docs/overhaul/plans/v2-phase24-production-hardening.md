# Phase 24: Production Hardening

Status: complete
Date: 2026-04-13

## Purpose

Close the retained runtime foundation track with runtime hardening,
deterministic release verification, and explicit diagnostics/performance
evidence across the retained Linux and web targets.

## Scope

Phase 24 covers:

- production diagnostics/runtime validation surfaces
- large-list performance guardrails for Live TV scale
- full regression proof across Rust, Flutter, Linux, and web
- release-state hygiene for Linux integration runs
- final docs/test-plan closure for the retained runtime foundation track

## Implemented

### Diagnostics runtime

- added retained diagnostics runtime surfaces in Flutter:
  - `features/shell/domain/diagnostics_runtime.dart`
  - `features/shell/data/diagnostics_runtime_repository.dart`
  - `features/shell/data/asset_diagnostics_runtime_repository.dart`
- bootstrap now resolves diagnostics runtime together with the rest of the
  retained runtime state
- Settings `System` now exposes a diagnostics panel for validation summary,
  tool readiness, and stream diagnostics cards

### Shared Rust crate usage

- `crispy-ffi` now consumes:
  - `crispy-stream-checker`
  - `crispy-media-probe`
- the retained diagnostics snapshot uses shared-crate logic for:
  - stream status categorization
  - URL normalization
  - resume hash derivation
  - resolution classification
  - resolution mismatch warnings
- host-tool availability probing remains in Rust through a separate
  host-dependent helper instead of contaminating deterministic retained assets

### Deterministic retained diagnostics asset

- `asset_diagnostics_runtime.json` is intentionally deterministic and
  machine-independent
- host-dependent `ffprobe` / `ffmpeg` availability is not allowed to change the
  retained asset-backed diagnostics snapshot used for bootstrap/tests
- host-tool availability is exposed separately in Rust for later runtime
  replacement

### Performance guardrail

- added `live_tv_large_list_test.dart` to verify the channel rail stays lazy at
  large list sizes instead of materializing far-off rows eagerly

## Verification

Required evidence that passed in this phase:

- `cargo test`
- `flutter analyze`
- Flutter retained runtime and shell suite including:
  - bootstrap
  - diagnostics runtime
  - large-list Live TV laziness
  - shell page/view-model/player/runtime tests
- `flutter test integration_test/main_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `flutter build web`
- browser-driven Playwright smoke against the built web app

## Closure result

Phase 24 is complete when all of the following are true:

- no known blocking regression remains in the retained runtime path
- diagnostics/runtime validation path exists and is documented
- retained diagnostics asset is deterministic across environments
- host-tool probing is separated from deterministic retained assets
- large-list laziness is explicitly test-covered
- Linux release state is regenerated after Linux integration runs
- Linux and web release builds succeed
- later post-foundation audit/completion phases are explicitly defined before
  product completion is discussed
