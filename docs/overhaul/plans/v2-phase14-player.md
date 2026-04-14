# Phase 14: Player Implementation

Status: UI-first retained-player baseline complete

## Scope

- Replace mock player handoff placeholders with the retained player surface.
- Keep player out of global navigation and out of shell route chrome.
- Preserve contextual back/unwind order from the installed player gate.
- Deliver the retained player baseline for the UI-first app, not the final
  player product.

## Completed Behavior

- movie detail launches the retained player overlay
- series episode launch opens player and supports in-player episode switching
- Live TV explicit tune/play action opens player and supports in-player channel
  switching
- player chooser overlays exist for audio, subtitles, quality, and source
- Back dismisses chooser overlays, then expanded info, then player exit

## Implementation Shape

- player state lives in the shared shell view-model
- player is rendered as an overlay, not as a top-level shell route
- repeated player chrome comes from shared role/theme code
- old mock-handoff language was removed from canonical content and tests
- player implementation follows the borrow/avoid rules in
  `v2-player-reference-study.md`

## Verification

- Flutter analyze/tests green
- Linux smoke/build green
- web build and browser smoke green

## Not closed by this phase

- final player visual/design completion
- final player control-language completion
- real playback/backend integration
- full production player implementation
