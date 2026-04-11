# V2 Focus Map Spec

Status: Phase-3 redone
Date: 2026-04-11

## Global focus regions

Focus moves between these regions in priority order:

1. top bar
2. sidebar, when the active domain has local navigation
3. content pane
4. overlay/modal, when present

## Global movement rules

- `MoveLeft` from content enters the sidebar when a sidebar exists
- `MoveLeft` from sidebar enters the top bar only when the sidebar is at its
  left-most escape boundary
- `MoveRight` from top bar enters sidebar when it exists, otherwise content
- overlays trap focus until dismissed

## Route-level initial focus

### Home

- initial focus: top bar
- next region: content
- no default sidebar

### Sources

- initial focus: top bar when entering from another domain
- after top-bar confirmation, first local target in sidebar
- content focus follows sidebar choice

### Live TV

- initial focus: top bar when entering Live TV
- next focus: local sidebar (`Channels` / `Guide`)
- next focus: content pane

### Media

- initial focus: top bar when entering Media
- next focus: local sidebar (`Movies` / `Series`)
- next focus: content pane

### Search

- initial focus: search entry or top-level search trigger
- no default persistent sidebar
- content results follow search entry

### Settings

- initial focus: top bar when entering Settings
- next focus: local sidebar (`General`, `Playback`, `Sources`, `Appearance`, `System`)
- next focus: content pane

### Player Placeholder

- initial focus: content pane
- no default persistent sidebar

## Live TV focus rule

- focus movement updates metadata only
- focus movement must not imply playback changes
- activation is explicit

## Media focus rule

- focused media card must visibly separate from passive neighbors
- focus movement stays within rails/grids until region escape

## Overlay focus rule

- overlays trap focus
- `Back` dismisses overlay before any route/domain unwind
- `Menu` inside overlay is overlay-local only

## Completion note

Phase 3 focus-map planning is complete for the current branch state:

- global focus-region priority is explicit
- per-domain initial-focus rules are explicit
- overlay trapping and unwind order align with the back/menu rules
- active focus docs align with the pinned shell planning and full spec
- implementation must keep these focus priorities visible in the route layouts,
  not only in code paths
