# V2 Phase 4 Shell Implementation Kickoff

Status: Phase-4 rebuilt from reset baseline
Date: 2026-04-11

## Execution target

Phase 4 must be executed from the cleaned restart baseline after phases 0
through 3 are explicitly confirmed as the active authority.

Required shell outcomes:

- top-bar global/domain navigation
- local sidebar only for approved domains
- content-first shell panes driven from the mock Rust snapshot contract
- route-local menu overlay
- back unwind behavior for overlay dismissal and local-surface fallback
- keyboard escape path for overlay-first back handling
- board-faithful shell composition per active route intent
- no generic placeholder shell surfaces counted as acceptable output

## Verification

- `flutter analyze`
- `flutter test test/core/theme/crispy_overhaul_tokens_test.dart test/core/theme/theme_test.dart test/features/shell/shell_page_test.dart`
- `flutter test integration_test/main_test.dart -d linux`
- `cargo test`
- `flutter build linux`
- `flutter build web`
- browser-rendered smoke verification of the built web target
- Linux release build after the rebuilt shell passes the design-faithful gate

## Completion note

The current Phase 4 shell was rebuilt from the empty baseline after the latest
reset.

Current branch result:

- Sources stays inside Settings
- Player stays out of top-level navigation
- Back and Menu stay out of the permanent global top bar
- installed design docs were used as implementation authority
- `design/reference-images/` remained the only visual reference set
- Linux and web verification passed for the rebuilt shell
