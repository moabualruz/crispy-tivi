# V2 Phase 23: Persistence, Resume, and Personalization

Status: complete
Date: 2026-04-13

## Purpose

Replace fake continue-watching, startup memory, and resume behavior with a real
persisted personalization runtime while keeping the retained Flutter shell on
stable repository/bootstrap boundaries.

## Authority

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. `design/docs/penpot-installed-design-system.md`
4. `docs/overhaul/plans/v2-implementation-reference-study.md`
5. `docs/overhaul/plans/v2-full-implementation-plan.md`

## Completed In This Phase

- Rust now owns the retained personalization runtime schema in
  [lib.rs](/home/mkh/workspace/crispy-tivi/rust/crates/crispy-ffi/src/lib.rs).
- Flutter now mirrors that schema in
  [asset_personalization_runtime.json](/home/mkh/workspace/crispy-tivi/app/flutter/assets/contracts/asset_personalization_runtime.json)
  and parses it through
  [personalization_runtime.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/domain/personalization_runtime.dart).
- Retained repository/bootstrap boundaries now carry personalization state:
  - [personalization_runtime_repository.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/personalization_runtime_repository.dart)
  - [asset_personalization_runtime_repository.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/asset_personalization_runtime_repository.dart)
  - [persisted_personalization_runtime_repository.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/persisted_personalization_runtime_repository.dart)
  - [shell_bootstrap_repository.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/shell_bootstrap_repository.dart)
  - [asset_shell_bootstrap_repository.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/asset_shell_bootstrap_repository.dart)
- Cross-platform retained persistence now exists:
  - Linux/desktop file-backed storage in
    [personalization_runtime_store_io.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/personalization_runtime_store_io.dart)
  - web `localStorage` in
    [personalization_runtime_store_web.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/data/personalization_runtime_store_web.dart)
- app bootstrap and retained presentation now hydrate from personalization:
  - [app.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/app/app.dart)
  - [shell_page.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/presentation/shell_page.dart)
  - [shell_view_model.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/presentation/view_model/shell_view_model.dart)
- Home continue-watching and Media recent/library/continue-watching now derive
  from personalization state instead of legacy `ShellContent` rails on the
  active runtime path.
- Player exit now persists resume position and recently-viewed state through the
  retained player/view-model path:
  - [player_view.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/presentation/routes/player_view.dart)

## Closure Notes

- startup-route memory, continue-watching, recent items, watchlist/library
  shaping, and resume position are now real persisted runtime state
- retained Flutter storage remains an adapter; Rust is the schema/rules
  authority and this boundary is prepared for later FFI replacement
- asset defaults still provide the initial personalization snapshot, but
  persisted state overrides them when available

## Verification Completed

- `cargo test`
- `flutter analyze`
- retained Flutter persistence/runtime suite:
  - `test/app/app_bootstrap_test.dart`
  - `test/features/shell/asset_shell_bootstrap_repository_test.dart`
  - `test/features/shell/personalization_runtime_test.dart`
  - `test/features/shell/persisted_personalization_runtime_repository_test.dart`
  - `test/features/shell/shell_view_model_test.dart`
  - `test/features/shell/shell_page_test.dart`
  - `test/features/shell/movie_view_test.dart`
  - `test/features/shell/playback_backend_test.dart`
  - `test/features/shell/player_view_test.dart`

## Next Allowed Lane

- `Phase 24: production hardening`
