# V2 Phase 19 Source / Provider Registry

Status: complete
Date: 2026-04-12

## Purpose

Phase 19 closes the retained source/provider boundary before real provider
syncing starts. The shell must stop deriving source state from legacy
`ShellContent` source cards and instead consume one Rust-owned source registry
contract from bootstrap through Settings-owned source flows.

## Output

- Rust owns the typed source/provider registry schema in `crispy-ffi`
- Flutter loads that registry through a retained `SourceRegistryRepository`
- bootstrap resolves contract, content, and source registry together
- Settings/source-flow view-model state derives from the runtime source
  registry instead of `ShellContentSnapshot.source_health_items`
- typed provider lanes exist for:
  - `M3U URL`
  - `local M3U`
  - `Xtream`
  - `Stalker`
- onboarding/auth/import step order and copy come from the runtime source
  registry contract
- asset-backed source registry remains explicit temporary infrastructure behind
  the retained repository interface

## Main files

- `rust/crates/crispy-ffi/src/lib.rs`
- `app/flutter/assets/contracts/asset_source_registry.json`
- `app/flutter/lib/features/shell/domain/source_registry.dart`
- `app/flutter/lib/features/shell/domain/source_registry_snapshot.dart`
- `app/flutter/lib/features/shell/data/source_registry_repository.dart`
- `app/flutter/lib/features/shell/data/asset_source_registry_repository.dart`
- `app/flutter/lib/features/shell/data/shell_bootstrap_repository.dart`
- `app/flutter/lib/features/shell/data/asset_shell_bootstrap_repository.dart`
- `app/flutter/lib/app/app.dart`
- `app/flutter/lib/features/shell/presentation/shell_page.dart`
- `app/flutter/lib/features/shell/presentation/view_model/shell_view_model.dart`
- `app/flutter/lib/features/shell/presentation/routes/settings_view.dart`

## Crate grounding

Phase 19 keeps the shell on the retained runtime boundary but pins the later
real implementation path:

- normalized shared vocabulary remains centered on `crispy-iptv-types`
- provider-specific later runtime work will continue through:
  - `crispy-m3u`
  - `crispy-xtream`
  - `crispy-stalker`
  - `crispy-iptv-tools`
  - `crispy-stream-checker`

## Guarantees

- the runtime source registry is a first-class retained contract surface
- bootstrap no longer treats source/provider state as route-local fixture data
- Settings-owned provider flows now have an explicit replacement path from
  asset-backed registry data to later Rust-backed runtime data
- legacy `ShellContent` source cards are now fallback-only for injected
  test/bootstrap paths, not the main runtime source of truth

## Verification

- `cargo test`
- `flutter analyze`
- `flutter test test/app/app_bootstrap_test.dart test/features/shell/asset_shell_contract_repository_test.dart test/features/shell/asset_shell_content_repository_test.dart test/features/shell/asset_shell_bootstrap_repository_test.dart test/features/shell/source_registry_snapshot_test.dart test/features/shell/asset_source_registry_repository_test.dart test/features/shell/shell_runtime_boundary_test.dart test/features/shell/shell_view_model_test.dart test/features/shell/shell_page_test.dart`
- `timeout 120s flutter test integration_test/main_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `flutter build web`
- browser-driven web smoke on the built web target
