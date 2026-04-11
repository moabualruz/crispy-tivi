# V2 Authority Reconciliation Plan

Status: Active
Date: 2026-04-11

## Problem

The repo currently contains conflicting visual inputs:

1. the conversation-history v2 spec
2. the live approved Penpot overhaul page
3. approved reference images under `design/reference-images/`
4. legacy screenshots under `docs/screenshots/`

The legacy screenshots show the older shipped left-rail shell and therefore
conflict with the active v2 shell model.

## Resolved authority order

For phases 1 to 4, use this order only:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. live approved Penpot page locked by
   `design/penpot/publish_app_overhaul_design_system.js`
3. approved reference images in `design/reference-images/`
4. active v2 planning docs
5. all other checked-in screenshots and older docs

## Consequence

- `docs/screenshots/` is historical evidence only
- legacy shipped-app captures must not drive shell structure decisions
- if a legacy screenshot conflicts with the active v2 shell model, the
  screenshot is wrong for v2 work

## Phase rebuild order

### Phase 1

- lock token and surface language
- keep shell chrome restrained
- remove decorative invention not justified by Penpot/spec/reference images

### Phase 2

- lock literal route composition rules
- map each route to the relevant board group and image cues
- forbid generic route recipes that flatten all domains into one layout system

### Phase 3

- lock shell ownership, focus priorities, and back/menu rules
- require those rules to stay visible in the layout structure itself

### Phase 4

- build only the shell mock
- use windowed primitives from day 1
- keep Flutter limited to view/view-model concerns
- defer Rust-owned domain orchestration until later phases
