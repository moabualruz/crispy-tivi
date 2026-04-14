# Phase 21: Media and Search Implementation

Status: complete
Date: 2026-04-13

## Purpose

Move the active `Media` and `Search` routes off legacy `ShellContentSnapshot`
fixtures and onto retained runtime repositories/snapshots that can later be
replaced by Rust-backed implementations without rewriting presentation code.

## Authority

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-full-implementation-plan.md`
3. `docs/overhaul/plans/v2-phase18-runtime-contract-reset.md`
4. `docs/overhaul/plans/v2-phase19-source-provider-registry.md`
5. `docs/overhaul/plans/v2-phase20-live-tv-epg.md`
6. `design/docs/penpot-installed-design-system.md`
7. active v2 plan docs

## Completed outputs

- Rust owns retained `MediaRuntimeSnapshot` and `SearchRuntimeSnapshot` schema
  producers in `crispy-ffi`
- Flutter exposes retained runtime repositories for media and search
- bootstrap resolves contract, content, source registry, live-TV runtime,
  media runtime, and search runtime together
- active `Media` presentation/view-model flow now consumes retained runtime
  state through a presentation adapter
- active `Search` presentation/view-model flow now consumes retained runtime
  state through a presentation adapter
- legacy `ShellContentSnapshot` movie/series/search fields are no longer the
  active runtime source for Media/Search route behavior
- legacy-content Media/Search fallback remains available only as data/bootstrap
  scaffolding for injected tests

## Files / ownership

### Rust schema authority

- `rust/crates/crispy-ffi/src/lib.rs`

### Flutter retained runtime/data

- `app/flutter/lib/features/shell/domain/media_runtime.dart`
- `app/flutter/lib/features/shell/domain/search_runtime.dart`
- `app/flutter/lib/features/shell/data/media_runtime_repository.dart`
- `app/flutter/lib/features/shell/data/search_runtime_repository.dart`
- `app/flutter/lib/features/shell/data/asset_media_runtime_repository.dart`
- `app/flutter/lib/features/shell/data/asset_search_runtime_repository.dart`
- `app/flutter/lib/features/shell/data/media_runtime_fallback.dart`
- `app/flutter/lib/features/shell/data/search_runtime_fallback.dart`
- `app/flutter/lib/features/shell/data/shell_bootstrap_repository.dart`
- `app/flutter/lib/features/shell/data/asset_shell_bootstrap_repository.dart`

### Flutter presentation integration

- `app/flutter/lib/features/shell/presentation/view_model/shell_view_model.dart`
- `app/flutter/lib/features/shell/presentation/shell_page.dart`
- `app/flutter/lib/features/shell/presentation/media/media_presentation_adapter.dart`
- `app/flutter/lib/features/shell/presentation/media/media_presentation_state.dart`
- `app/flutter/lib/features/shell/presentation/search/search_presentation_adapter.dart`
- `app/flutter/lib/features/shell/presentation/search/search_presentation_state.dart`
- `app/flutter/lib/features/shell/presentation/routes/media_view.dart`
- `app/flutter/lib/features/shell/presentation/routes/search_view.dart`

### Asset-backed temporary runtime inputs

- `app/flutter/assets/contracts/asset_media_runtime.json`
- `app/flutter/assets/contracts/asset_search_runtime.json`

## Anti-drift rules

- Active Media/Search route behavior must come from retained media/search
  runtime snapshots, not from `ShellContentSnapshot`
- Legacy-content Media/Search fallback belongs in data/bootstrap only
- Routes and view-models may adapt retained runtime into presentation state, but
  they must not construct legacy fallback runtime state locally
- Asset-backed runtime repositories remain temporary implementations behind the
  retained repository interfaces defined in Phase 18

## Verification

- `cargo test`
- `flutter analyze`
- retained Flutter runtime/presentation tests for:
  - media/search runtime snapshots
  - asset-backed media/search repositories
  - bootstrap runtime boundary
  - shell view-model / shell page
  - Media/Search route behavior
- `flutter test integration_test/main_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `flutter build web`
- browser-driven web smoke against the built web target
