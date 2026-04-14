# V2 Phase 20 Live TV / EPG Runtime

Status: complete
Date: 2026-04-13

## Purpose

Phase 20 closes the retained Live TV / EPG runtime lane before Media/Search and
playback backend work proceed further.

This phase moves the active Live TV runtime path off the old shell-content
fixtures and onto a retained runtime boundary that matches the Rust-owned
`crispy-ffi` schema.

## Scope Closed Here

- Rust owns the canonical `LiveTvRuntimeSnapshot` schema and asset shape.
- Flutter now loads the live-TV runtime through a retained repository
  interface.
- shell bootstrap carries:
  - contract
  - content
  - source registry
  - live TV runtime
- the active Live TV route consumes the retained runtime snapshot for:
  - browse groups
  - channel rows
  - guide rows
  - selected-detail lane
  - player launch metadata

## Required Rules

- Live TV browse groups must come from the retained live-TV runtime, not from
  contract-era enum heuristics.
- guide rows must come from the retained live-TV runtime, not from legacy
  `ShellContent` string-table guide rows.
- selection/detail lane must stay synchronized to the same retained runtime
  snapshot as browse and guide.
- legacy `ShellContent` live-TV fields may remain only as explicit fallback for
  injected test/bootstrap scaffolding while older tests are still being moved.
- legacy-content fallback must be constructed in data/bootstrap adapters only.
  Do not keep legacy-to-runtime fallback factories inside
  `domain/live_tv_runtime.dart`, and do not build fallback runtime state
  directly inside routes or view-models.

## Files

Core runtime boundary:

- `rust/crates/crispy-ffi/src/lib.rs`
- `app/flutter/assets/contracts/asset_live_tv_runtime.json`
- `app/flutter/lib/features/shell/domain/live_tv_runtime.dart`
- `app/flutter/lib/features/shell/data/live_tv_runtime_repository.dart`
- `app/flutter/lib/features/shell/data/asset_live_tv_runtime_repository.dart`
- `app/flutter/lib/features/shell/data/shell_bootstrap_repository.dart`
- `app/flutter/lib/features/shell/data/asset_shell_bootstrap_repository.dart`
- `app/flutter/lib/app/app.dart`
- `app/flutter/lib/features/shell/presentation/shell_page.dart`
- `app/flutter/lib/features/shell/presentation/view_model/shell_view_model.dart`
- `app/flutter/lib/features/shell/presentation/routes/live_tv_view.dart`

Tests:

- `app/flutter/test/app/app_bootstrap_test.dart`
- `app/flutter/test/features/shell/live_tv_runtime_snapshot_test.dart`
- `app/flutter/test/features/shell/asset_live_tv_runtime_repository_test.dart`
- `app/flutter/test/features/shell/asset_shell_bootstrap_repository_test.dart`
- `app/flutter/test/features/shell/shell_runtime_boundary_test.dart`
- `app/flutter/test/features/shell/shell_view_model_test.dart`
- `app/flutter/test/features/shell/live_tv_view_test.dart`
- `app/flutter/test/features/shell/shell_page_test.dart`

## Verification

Phase 20 closes only when all of the following are green on the integrated
state:

- `cargo test`
- `flutter analyze`
- targeted runtime/shell/live-TV Flutter tests
- `flutter test integration_test/main_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `flutter build web`
- browser-driven web smoke on the built web target

## Closure

Phase 20 is complete when:

- the retained live-TV runtime path is the active browse/guide/detail source
- heuristic group slicing is removed from the active route path
- legacy fallback construction lives in data/bootstrap, not retained domain or
  presentation layers
- docs and tests are updated in the same pass
- the next allowed lane becomes `Phase 21`
