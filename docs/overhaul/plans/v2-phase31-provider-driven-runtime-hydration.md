# Phase 31: Provider-Driven Runtime Hydration

Status: complete
Date: 2026-04-13

## Purpose

Phase 31 removes the "persisted providers but empty runtime" gap from real
boot. Configured providers now hydrate retained runtime snapshots for Home,
Live TV, Media, and Search instead of leaving the real path visually empty
after setup/import.

## Completed in this phase

- widened the retained real bootstrap boundary so it now loads:
  - persisted configured providers
  - retained template runtime snapshots
  - persisted personalization runtime
  - diagnostics runtime
- added retained configured-provider hydration in data/bootstrap code instead of
  presentation/view-model code
- hydrated retained runtime lanes from configured-provider capability truth:
  - Live TV
  - Media
  - Search
- kept unsupported lanes empty rather than lighting them up from unrelated
  providers
- fixed raw source-registry persistence so configured-provider `display_name`
  and `endpoint_label` survive save/load and can be used by the hydrated
  runtime path

## Evidence

- retained tests now verify:
  - configured providers hydrate retained runtime snapshots on real boot
  - hydration is capability-selective and does not populate unsupported lanes
  - persisted personalization remains present on the real hydrated path
- verification passed:
  - `flutter analyze`
  - `flutter test test/app/app_bootstrap_test.dart test/features/shell`
  - `timeout 120s flutter test integration_test/main_test.dart -d linux`
  - `app/flutter/tool/restore_linux_release_state.sh`
  - `flutter build linux`
  - `flutter build web`
- built-web browser smoke:
  - `.playwright-cli/phase31-web-smoke.png`
  - `.playwright-cli/page-2026-04-13T11-18-59-968Z.yml`

## Closure rule

Phase 31 closes provider-driven retained runtime hydration only. It does not
yet make the shared Rust provider crates active in the runtime crate graph;
that belongs to Phase 32.
