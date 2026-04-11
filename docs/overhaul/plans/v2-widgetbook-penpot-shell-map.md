# V2 Widgetbook and Installed Design Shell Map

Status: Phase-2 active planning baseline
Date: 2026-04-11

## Installed design boards and ownership

### `FOUNDATION - vNext Tokens`

Owns:

- vNext surfaces, accents, semantic, and text tokens
- spacing, radius, and motion references

### `FOUNDATION - Layout and Windowing`

Owns:

- `32/68` and `36/64` shell splits
- fake-scroll/windowed composition rules
- viewport-safe content geometry

### `COMPONENT - Navigation and Focus Controls`

Owns:

- top-bar global navigation states
- local/domain side navigation states
- focus readability and activation affordances

### `COMPONENT - Surfaces and Widget Feel`

Owns:

- panel, raised, glass, and overlay surface direction
- focus ring and elevation interaction language

### `SCREEN - Home Shell`

Owns:

- default shell composition
- top navigation over dominant content behavior

### `SCREEN - Settings and Sources Flow`

Owns:

- utility/global-entry treatment for settings
- wizard and source-flow shell composition

### `SCREEN - Live TV Channels`

Owns:

- replacement-flow channel browsing
- channel-list dominant composition

### `SCREEN - Live TV Guide`

Owns:

- guide layout and time-density behavior
- guide-specific focus movement expectations

### `SCREEN - Media Browse and Detail`

Owns:

- movie and series browsing composition
- detail handoff structure

### `SCREEN - Search and Handoff`

Owns:

- search-result structure
- canonical handoff from search into domain detail

### `FEATURE - Source Selection and Health`

Owns:

- source status surfacing
- source selection, validation, and health affordances

### `FEATURE - Favorites, History, and Recommendations`

Owns:

- recommendation rails
- continue-watching/history presentation

### `FEATURE - Mock Player and Full Player Gate`

Owns:

- mock-player launch contract
- explicit player gate and non-implementation rule

### `PATTERN - Left and Right Menus`

Owns:

- left-origin and right-origin utility menu patterns
- mirrored overlay/menu behavior

## Widgetbook specimen groups required after reset

1. foundation token specimens
2. layout and windowing specimens
3. navigation and focus specimens
4. shell surface specimens
5. route-level shell specimens
6. feature handoff specimens

## Current runtime note

`app/flutter/lib/widgetbook.dart` is not present on the clean restart baseline.
This artifact remains a planning contract until implementation restarts from the
pinned design baseline.

## Current expectation

Phase 2 ownership mapping remains active for the current branch state:

- each approved board has an explicit shell/planning responsibility
- specimen groups map to the fourteen-board approved overhaul baseline
- Phase 4 shell work must stay inside these ownership boundaries to remain
  compliant
