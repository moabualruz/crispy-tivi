# V2 Phase 22: Playback Backend Integration

Status: complete
Date: 2026-04-13

## Purpose

Connect the retained CrispyTivi player UI to a real playback backend without
replacing the product-owned player chrome.

## Authority

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. `design/docs/penpot-installed-design-system.md`
4. `docs/overhaul/plans/v2-player-reference-study.md`
5. `docs/overhaul/plans/v2-full-implementation-plan.md`

## Completed In This Phase

- `media_kit`, `media_kit_video`, and `media_kit_libs_video` are now part of
  the retained Flutter runtime.
- app startup initializes `MediaKit` in
  [app/flutter/lib/main.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/main.dart).
- the retained player route now renders a real backend video surface through
  `media_kit` while preserving the CrispyTivi player overlay language in
  [player_view.dart](/home/mkh/workspace/crispy-tivi/app/flutter/lib/features/shell/presentation/routes/player_view.dart).
- Rust runtime schema now carries explicit playback metadata for:
  - Live TV channels
  - movie items
  - series items
  - episode items
- Flutter runtime models now parse that playback metadata from:
  - [asset_live_tv_runtime.json](/home/mkh/workspace/crispy-tivi/app/flutter/assets/contracts/asset_live_tv_runtime.json)
  - [asset_media_runtime.json](/home/mkh/workspace/crispy-tivi/app/flutter/assets/contracts/asset_media_runtime.json)
- Live TV and Media player launches now resolve from runtime-backed
  `playback_source` and `playback_stream` metadata instead of hardcoded demo
  URLs in presentation code.
- runtime-backed player chooser groups now derive from the retained playback
  option catalog instead of static presentation-only text lists
- source and quality chooser selections now resolve the active playback target
  from runtime metadata
- audio and subtitle chooser selections now apply directly against the playback
  backend through `media_kit`
- legacy-content playback fallback generation now lives only in data/bootstrap
  fallback helpers.

## Closure Notes

- runtime playback option catalogs now exist end-to-end in:
  - Rust schema
  - Flutter runtime assets
  - retained Flutter runtime/domain parsing
  - retained player session state
  - retained player backend application
- chooser state is now real playback state, not decorative UI-only state
- the retained CrispyTivi player chrome remains product-owned while the backend
  is real

## Verification Completed

- `cargo test`
- `flutter analyze`
- retained Flutter playback/runtime suite:
  - `test/features/shell/playback_backend_test.dart`
  - `test/features/shell/player_view_test.dart`
  - `test/features/shell/movie_view_test.dart`
  - `test/features/shell/live_tv_view_test.dart`
  - `test/features/shell/media_runtime_snapshot_test.dart`
  - `test/features/shell/asset_live_tv_runtime_repository_test.dart`
  - `test/features/shell/asset_media_runtime_repository_test.dart`
  - `test/app/app_bootstrap_test.dart`
  - `test/features/shell/shell_runtime_boundary_test.dart`
- `flutter test integration_test/main_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `flutter build web`
- built-web Playwright smoke:
  - [phase22-web-smoke.png](/home/mkh/workspace/crispy-tivi/.playwright-cli/phase22-web-smoke.png)
  - [page-2026-04-13T00-37-20-521Z.yml](/home/mkh/workspace/crispy-tivi/.playwright-cli/page-2026-04-13T00-37-20-521Z.yml)

## Linux Native-Plugin Note

The Linux `media_kit_libs_linux` build can fail if a corrupted
`mimalloc-2.1.2.tar.gz` remains in `build/linux`. When that happens:

1. remove the corrupted archive from the Linux build tree
2. rerun
   [restore_linux_release_state.sh](/home/mkh/workspace/crispy-tivi/app/flutter/tool/restore_linux_release_state.sh)
3. rebuild Linux before manual launch

This is a native-plugin build-state issue, not a retained-player UI issue.
