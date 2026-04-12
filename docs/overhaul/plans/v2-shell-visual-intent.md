# V2 Shell Visual Intent

Status: Phase-2 redone
Date: 2026-04-11

## Global intent

- modern Google TV / Android TV shell behavior
- Apple TV-like focus, scale, depth, and motion restraint
- cinematic but readable dark surfaces
- less pure-black stacking
- clearer elevation separation

## Shell composition

- top bar: global/domain navigation
- side panel: current-domain local navigation only
- content pane: active surface
- overlays: modal flows above content
- no permanent `Back` or `Menu` controls in the global top bar
- no old-app underline/underscore nav cue
- no pills ever
- no chip-heavy shell chrome
- top shell should read closer to a shared grouped control than to isolated
  outline buttons
- the selected nav highlight must belong to the same control geometry, not read
  like a different component inserted into it
- shell surfaces should carry slightly warmer/translucent Google TV / Apple TV
  influence instead of flat black stacked rectangles
- settings/profile entry belongs to the right-side utility area, not the main
  domain-nav group
- active palette direction is `Smoked Stone`
- use restrained glassy grouped chrome with neutral highlights, not tinted
  neon-like washes
- do not use decorative blue or red color washes on artwork
- route-level chrome must inherit the active token palette rather than carrying
  stale hardcoded colors
- the full window backdrop must feel intentional and palette-aligned; outer
  space must not read as dead black margins
- selected/focused/active states must share one visual language across the app
- sidebar selection must align with top-nav and in-content selection treatment,
  not use its own one-off indicator pattern
- interactive controls must share one corner language across the app
- continue-watching actions, hero actions, search field, settings info plate,
  sidebar selections, utility buttons, and profile tile must not drift into
  separate radius values
- shared corner language must stay restrained; do not make controls pill-like
  while chasing consistency
- when a drift is fixed in implementation, the active docs/plans must be
  corrected in the same pass
- scale behavior must preserve the same visual composition across sizes and
  windows
- `1080p` readability and `4K` shell fill must both be solved without changing
  the shell’s internal feel from one size to another
- current implementation uses one fixed virtual shell stage with one internal
  metric set; only presentation scale changes
- widget-level colors/radii/state geometry must come from the shared theme-role
  code authority, not from repeated per-widget literals
- shared shell backdrop, stage frame, hero chrome, artwork scrims, action
  controls, settings icon plates, and reusable media-card surfaces must also
  come from that shared role authority
- repeated hero/shelf media rendering should come from one shared media-surface
  system rather than local image-widget treatment
- that media-surface system must support mock assets now plus remote artwork
  later without changing route/widget composition code
- populated route content should come from canonical snapshot assets rather than
  route-local Dart seed constants when the snapshot path exists
- the shell stage must read product-sized at `1080p`; if the UI feels tiny,
  fix the virtual stage system rather than padding individual widgets larger
- large windows must not reintroduce dead surround area through an undersized
  virtual stage

## Route emphasis

### Home

- hero-led
- Continue Watching / Live Now / Media Spotlight / Recent Sources
- use populated hero/backdrop and poster imagery in mocks so Home opens like a
  real TV surface, not an empty wireframe
- populated hero/shelf imagery must stay domain-relevant; arbitrary pet/photo
  placeholders are drift even when the layout itself is correct
- populated hero/shelf imagery must also stay visibly legible inside the real
  shell crop and scrim; if artwork reads like an empty dark block, Phase 4 is
  not complete
- delayed or missing artwork must fall back through the same shared media
  surface path rather than route-specific placeholder logic
- restrained title-safe overlays inside artwork regions are allowed when they
  improve TV-distance readability without turning the shell into a poster wall
- Home shortcuts must not bypass the Settings-owned source-management rule;
  `Sources` is not a stand-alone Home quick-access destination
- tighten outer shell spacing so Home feels full-screen and product-like rather
  than centered inside large dead gutters
- use neutral readability scrims and meaningful progress/status markers only

### Live TV

- information-dense but remote-safe
- no implication that focus equals playback
- panels, preview stages, channel rows, and guide cells should reuse the shared
  shell-role surface system rather than route-private decoration patterns
- Channels should read as:
  - local panel nav in the sidebar
  - group rail inside content
  - dense channel list on the left
  - selected-channel detail/preview on the right
- Guide should read as:
  - group rail plus selected-channel summary on the left
  - preview/detail pane above
  - time-matrix guide below

### Media

- poster/rail-driven
- focused media card must clearly separate from passive neighbors
- mock media rails should render artwork, not abstract blocks, when assets are
  available
- Movies and Series must not feel like the same route with renamed labels:
  - Movies should lead with featured/film browsing emphasis
  - Series should lead with continuity/next-up emphasis
  - shelf ordering and scope cues should make that difference visible

### Search

- explicit query/result scope
- canonical handoff feel, never provider-native feel
- global search is for live/media content, not a top-level settings result hub
- result rows should use the same shared system-owned inset surface language as
  the rest of the shell
- Search should open like a content handoff surface:
  - strong route intro
  - explicit global-content scope cue
  - right-side handoff/support panel
  - artwork-backed result cards instead of plain utility rows

### Settings

- stable grouped hierarchy
- source management lives here as part of the grouped utility hierarchy
- should read closer to Google TV utility/settings behavior than to a media hub
- use utility-menu markers: icons, row values, chevrons, and clear section
  rhythm
- source onboarding/auth/import must read like one continuous Settings-owned
  flow:
  - source list and source detail first
  - ordered wizard steps second
  - reconnect/auth-needed entry reuses the same wizard lane
  - backing out of the first wizard step returns to source overview rather than
    ejecting the user out of Settings
- non-source settings groups should still open with a stronger section header
  and summary so the utility stack feels deliberate rather than flat
- source management should keep a clear ownership cue that this is still a
  Settings surface:
  - banner/ownership reminder
  - list/detail split
  - wizard rail only when wizard is active

## Completion note

Phase 2 route-level visual intent is complete for the current branch state and
is aligned with the pinned Penpot baseline plus the shell IA rule set.

This route-intent document is a literal composition contract for shell work. If
the rendered mock shell falls back to generic placeholder cards, generic
Material scaffolding, or route layouts that contradict these route emphases,
Phase 4 is not complete.

Verification for this intent must include both Linux and web rendered smokes,
with browser capture on web and route-level review against Penpot/reference
images before phase closure.
