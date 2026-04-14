# Phase 27: Provider/Controller Wiring Completion

Status: complete
Date: 2026-04-13

## Purpose

Phase 27 finishes the provider/runtime truth path so source onboarding and
management stop being partially-scaffolded UI over retained runtime shapes.

## Required outcomes

- provider setup/auth/import/edit/reconnect flows are backed by retained
  runtime/controller ownership
- provider-specific forms expose valid field types, valid option sets, and
  validation/error states from runtime/controller truth
- visible source status/health/import progress is runtime-backed
- the provider-controller boundary explicitly records whether shared Rust
  provider crates are already active or still pending follow-on runtime
  execution work

## Minimum provider coverage

- M3U URL
- local M3U
- Xtream
- Stalker

## Closure rules

Phase 27 is complete only when:

- the add/edit/reconnect flows are not just typed UI shells
- provider-specific behavior is not driven by fixture-only option sets
- docs clearly record the runtime/controller ownership for the provider lane
- if shared Rust provider crates are not yet active in the runtime crate graph,
  the phase docs say so explicitly instead of implying end-to-end provider
  execution

## Completed work

- provider setup/auth/import/edit/reconnect now runs through the retained
  `SourceSetupController` state machine instead of view-model-local wizard
  booleans and loose field maps
- provider kinds no longer collapse `M3U URL` and `local M3U` into one fake
  presentation type; the active runtime/controller path preserves:
  - `M3U URL`
  - `local M3U`
  - `Xtream`
  - `Stalker`
- add, edit, reconnect, and import all commit through the same retained
  controller path and update configured-provider state
- Settings source detail actions now route into:
  - reconnect
  - edit provider
  - import flow
  instead of bouncing back into generic add-provider behavior
- shared Rust provider crates are still not active in the current runtime crate
  graph; this phase closes retained controller ownership first and leaves real
  provider execution/validation crate usage for the later runtime-audit and
  release-readiness phases

## Verification evidence

- `flutter analyze`
- `flutter test test/features/shell/source_setup_controller_test.dart test/features/shell/shell_view_model_test.dart test/features/shell/shell_page_test.dart`

## Result

- provider flow ownership is now explicit in retained runtime/controller code
- the next allowed lane is `Phase 28`
