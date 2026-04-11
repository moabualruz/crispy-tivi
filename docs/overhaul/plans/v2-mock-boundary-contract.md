# V2 Mock Boundary Contract

Status: Active
Date: 2026-04-11

## Purpose

Define the minimal allowed mock integration between Rust and Flutter for the
restart lane.

## Boundary rule

- Rust owns mock domain/controller outputs only.
- Flutter owns parsing, view-model projection, focus/runtime behavior, and
  shell rendering only.
- Flutter must not contain controller or business orchestration.
- Rust must not own layout geometry, pixel styling, or directional focus
  rendering.

## Canonical mock handoff

The canonical mock handoff artifact is:

- `app/flutter/assets/mocks/shell_snapshot.json`

That artifact represents a Rust-owned shell/domain snapshot serialized as JSON.

## Required mock flow

1. Rust defines the snapshot schema and a mock snapshot producer.
2. Rust verifies that its produced JSON matches the canonical snapshot shape.
3. Flutter loads the canonical snapshot.
4. Flutter maps the snapshot into a shell view-model.
5. Flutter renders a design-faithful mock shell from that view-model.

## Allowed mock scope

- top-bar domain state
- sidebar section state
- route headline and summary copy
- content rails/cards/list summaries
- source-health summaries
- placeholder player gate state

## Disallowed mock scope

- real provider translation
- real playback
- real source syncing
- real search backend
- real pagination/business policies hidden inside Flutter
