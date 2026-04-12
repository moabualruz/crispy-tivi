# V2 Player Reference Study

Status: active
Date: 2026-04-12

## Purpose

This document records what CrispyTivi should take and should reject from the
player reference set.

It exists to prevent player UX drift during Phase 14 and Phase 15.

## Authority

Use this order:

1. `AGENTS.md`
2. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
3. `design/docs/penpot-installed-design-system.md`
4. this file
5. approved player-related reference images in `design/reference-images/`

This study does not override the spec or installed design system. It explains
how to implement them cleanly.

## Study Set

Local study sources used:

- `for_study/Megacubo`
- `for_study/hypnotix`
- `for_study/iptvnator`
- `for_study/player-ui-study/media-kit`
- `for_study/player-ui-study/chewie`
- `for_study/player-ui-study/rein_player`
- `for_study/player-ui-study/fvp`
- existing local visual references under `design/reference-images/`

## High-Level Decision

Backend direction:

- use `media_kit` as the preferred playback foundation
- `video_player_media_kit` remains acceptable as a migration bridge if needed
- do not let a third-party control package become the CrispyTivi visual
  authority

UI direction:

- CrispyTivi keeps its own player UI, transport, overlays, and queue behavior
- third-party player projects are reference inputs, not drop-in product UI

## What We Take

### From media_kit

Take:

- cross-platform playback confidence for Linux and web
- playlist/next/previous/jump capabilities
- audio/subtitle track selection
- external subtitle/audio track support
- screenshot support
- custom-controls-first mindset
- subtitle styling support

Use in CrispyTivi:

- one retained player surface
- same player foundation for live, movie, and episode playback
- explicit support for in-player sibling switching
- chooser overlays for audio, subtitles, quality, and source

### From chewie

Take:

- clear options grouping
- explicit subtitle and playback option entry points
- customizable options presentation instead of hard-wired UI

Use in CrispyTivi:

- chooser overlays remain modular
- each chooser is a separate contextual overlay
- options are grouped by responsibility, not dumped into one overloaded strip

Do not take:

- bottom-sheet-heavy mobile presentation
- generic Material player chrome
- phone-first fullscreen assumptions

### From ReinPlayer

Take:

- serious desktop/player mentality instead of “embedded video widget” thinking
- persistent playback context
- context-aware keyboard behavior
- playlist/queue importance
- seek preview and richer media-adjacent overlays
- right-click/contextual utility model as a secondary affordance
- subtitle customization depth

Use in CrispyTivi:

- queue/sibling switching must feel like a first-class player capability
- player should support keyboard-first usage cleanly
- player should own richer overlays later:
  - seek preview
  - stats/media analysis
  - bookmark/history style affordances if later approved

Do not take:

- PotPlayer-like density everywhere
- desktop-app utility chrome leaking into the TV shell
- cluttered always-on controls

### From fvp

Take:

- desktop-oriented playback seriousness
- backend API flexibility
- snapshot/record/external-subtitle style extensibility
- strong track and decoder capability awareness

Use in CrispyTivi:

- keep the player model extensible for later:
  - external subtitles
  - richer track selection
  - diagnostics/stats overlays
  - advanced playback capabilities

Do not take:

- backend-driven UI assumptions
- low-level capability exposure directly in primary transport chrome

## What CrispyTivi Should Feel Like

### Primary UX influence

- Netflix + YouTube for player information hierarchy and directness
- Megacubo + Hypnotix + IPTVnator for IPTV-native action naming, option
  grouping, and player/sidebar semantics

Meaning:

- transport must be obvious immediately
- metadata must be concise and readable
- episode/live switching must be visible without becoming noisy
- OSD states should step up in density only when requested
- action wording must stay product-simple:
  - `Resume`
  - `Restart`
  - `Next Episode`
  - `Go Live`
  - `Audio`
  - `Subtitles`
  - `Quality`
  - `Source`
- do not drift into verbose labels like `Resume playback`, `Resume episode`,
  `Watch from start`, or other invented wording when shorter IPTV/player
  language is clearer

### Shell fit

- Google TV first for low-chrome full-screen presentation and readable spacing
- Apple TV restraint for motion, glass, and edge treatment only

Meaning:

- player must feel like part of CrispyTivi’s design system
- player must not look like an imported generic player package
- player must not feel like a separate product from the shell

## CrispyTivi Player Requirements

### Structural requirements

- player is an overlay, not a top-level route
- player must not appear in global navigation
- movie detail, series episode, and Live TV tune all enter the same player
  system
- player state must remain view-model/system owned, not route-local

### OSD requirements

- base transport state:
  - title
  - subtitle/context
  - progress/live-edge state
  - icon-led transport controls
  - icon-led utility controls for audio, subtitles, quality, and source
  - contextual text should live in labels, badges, and overlays rather than a
    row of verbose action buttons
- expanded info state:
  - richer badges
  - summary
  - queue/sibling switching
  - stats/supporting metadata
- chooser overlays:
  - audio
  - subtitles
  - quality
  - source

### Switching requirements

- Live TV:
  - next/previous/sibling channel switching without exiting player
- Series:
  - next/previous/sibling episode switching without exiting player
- Movies:
  - up-next stays secondary, not louder than primary playback

### Back/unwind requirements

- Back closes chooser overlay first
- Back collapses expanded info second
- Back exits player last
- no permanent global menu button in the player

### Visual requirements

- full-screen, content-first stage
- restrained transport glass, not loud panel stacking
- no pill-heavy transport controls
- transport should read like a TV/video OSD, not a row of app action chips
- player chrome must not be text-only; chooser lanes, metadata badges, and
  secondary utility actions should use coherent icon support from the shared
  shell icon system
- do not turn transport and chooser controls into redundant icon+text buttons
  when text already communicates the action clearly
- use icon-only for obvious universal player affordances like Back when the
  accessibility label preserves the text meaning; keep icon+text only where the
  icon adds a useful extra cue instead of restating the same action
- player control geometry must still match the rest of the shell control
  system; icon-only transport and utility controls keep the same height as
  text-bearing shell controls, and `LIVE` remains an icon+text state treatment
- player design previews must use the same real icon artwork language as the
  app instead of placeholder glyph characters, so the preview does not teach
  the wrong icon system back into implementation
- no mobile-bottom-sheet feeling
- subtitles and controls must not fight each other for the same vertical zone

## What We Will Implement Next

### Keep

- retained player overlay architecture
- shared player surface for live, movie, and series playback
- chooser overlays
- in-player live/episode switching

### Improve in later passes

- stronger transport layout polish
- subtitle positioning behavior when controls are visible
- richer seek preview
- richer stats/media-analysis overlay
- better keyboard/remote affordances
- more explicit up-next modeling for movies and series
- eventual backend swap from asset-backed fake playback data to Rust/FFI-backed
  playback envelopes

### Explicit non-goals for now

- backend playback finalization
- DRM/protected-stream handling
- casting/PiP/miniplayer
- deep subtitle customization UI
- advanced desktop utility menus

## Anti-Drift Rules

- do not import third-party player chrome wholesale
- do not let backend package capabilities dictate product UI hierarchy
- do not reintroduce mock-only wording once retained player behavior exists
- do not create separate movie player, series player, and live player UIs
- do not move player logic into route-local widgets
- do not let player overlays drift away from the shared shell role system
