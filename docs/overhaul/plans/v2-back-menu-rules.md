# V2 Back and Menu Rules

Status: Phase-3 redone
Date: 2026-04-11

## Back priority

Back always unwinds in this order:

1. active overlay/modal
2. local route state within the current domain
3. current domain back to its primary local surface
4. current domain back to the previously active global domain

## Menu priority

Menu opens only route-local or overlay-local actions.

Menu is not a permanent top-bar control unless the approved Penpot design
explicitly shows it.

Menu must not:

- replace Back
- switch global domains
- act as a hidden global navigation shortcut

## Domain-specific back behavior

### Home

- Back from Home stays in Home unless an overlay is open

### Live TV

- Guide -> back to Channels
- Back from Channels -> previous global domain

### Media

- Series -> back to Movies or previous media-local landing surface
- Back from media-local landing surface -> previous global domain

### Search

- Back from result detail state -> search results
- Back from search results -> previous global domain

### Settings

- Sources list/detail/import unwind inside Settings before leaving Settings
- Back from local settings group content -> settings group list if needed
- Back from settings root -> previous global domain

## Menu examples

- Live TV: view options or guide/channel-local options
- Media: filter/sort/view options
- Search: scope/filter options
- Settings: group-local options

## Non-goals

- Back directly skipping overlays
- Menu acting as a second back stack
- hidden global-domain changes via Menu

## Completion note

Phase 3 back/menu planning is complete for the current branch state:

- unwind priority is explicit
- domain-specific back behavior is explicit
- Menu remains route-local or overlay-local only
- active back/menu rules align with the IA and focus-map docs
- shell verification must prove these rules in the rendered mock, not only in
  internal state handling
