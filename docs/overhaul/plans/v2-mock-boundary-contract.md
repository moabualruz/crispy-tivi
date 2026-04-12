# V2 Mock Boundary Contract

Status: Phase-5 complete
Date: 2026-04-11

## Purpose

Define the minimal allowed asset-backed fake integration between Rust and
Flutter for the restart lane while keeping the retained shell runtime neutral.

## Boundary rule

- Rust owns mock domain/controller outputs only.
- Flutter owns parsing, view-model projection, focus/runtime behavior, and
  shell rendering only.
- Flutter must not contain controller or business orchestration.
- Rust must not own layout geometry, pixel styling, or directional focus
  rendering.
- shared shell domain, contract, navigation, view-model, and presentation code
  must keep neutral production names
- only fixture assets, fake repositories, and test harnesses may keep explicit
  `mock`, `fake`, or `asset` naming

## Canonical mock handoff

The canonical shell contract artifacts are:

- `rust/crates/crispy-ffi/src/lib.rs`
- `app/flutter/assets/contracts/asset_shell_contract.json`
- `app/flutter/assets/contracts/asset_shell_content.json`

The canonical asset-backed shell runtime consumes:

- `app/flutter/assets/contracts/asset_shell_contract.json`
- `app/flutter/assets/contracts/asset_shell_content.json`

Those artifacts represent Rust-owned shell/domain contracts serialized as JSON.

## Required mock flow

1. Rust defines the shell contract schema and a mock contract producer.
2. Rust verifies that its produced JSON matches the canonical contract shape.
3. Rust defines a canonical shell content snapshot shape for populated shell
   route surfaces.
4. Flutter loads the canonical contract assets.
5. Flutter validates and maps the shell contract into route/panel/scope
   support.
6. Flutter consumes the canonical content snapshot for populated Home, Live TV,
   Media, Search, and Settings rendering.
7. Flutter initializes the shell view-model from the contract.
8. Flutter renders a design-faithful shell from contract-backed state and
   content snapshots.
9. The asset-backed bootstrap must resolve once and settle into the shell;
   contract/content loading must not loop on rebuild.
10. Phase-6 source onboarding/auth/import flow ordering must come from the
    contract/content pair rather than hidden widget-local defaults.

## Allowed mock scope

- top-bar domain state
- startup route ownership
- sidebar section state
- allowed route/panel/group/scope ordering
- route headline and summary copy
- content rails/cards/list summaries
- source-health summaries
- source detail surfaces
- source wizard step ordering
- source wizard step copy/content
- placeholder player gate state

## Disallowed mock scope

- real provider translation
- real playback
- real source syncing
- real search backend
- real pagination/business policies hidden inside Flutter
