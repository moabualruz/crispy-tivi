# Phase 13: Player Pre-Code Design Gate

Status: complete

## Scope

- Close the player design gate before any player implementation starts.
- Use repo-local installed design docs and reference images as authority.
- Define the player behavior matrix, overlay rules, and back/unwind rules in
  implementation-facing Markdown.

## Reference Set

Phase 13 is grounded by these local references:

- `design/reference-images/tv-ui-2026/google-tv-flatpanelshd-home.jpg`
- `design/reference-images/tv-ui-2026/google-tv-techcrunch.webp`
- `design/reference-images/tv-ui-2026-more/google-tv-techradar-redesign.jpg`
- `design/reference-images/tv-ui-2026-more/apple-tv-macrumors-tvos26.jpg`
- `design/reference-images/tv-ui-2026-more/apple-tv-macrumors-tvos26-feature.jpg`
- `design/reference-images/tv-ui-2026/netflix-reference-thetab.png`

These references drive player chrome behavior, OSD density, and transport
restraint. They do not override the v2 spec or the installed design system.

## Completed Design Gate

The player gate is now defined in the repo-local design authority:

- `design/docs/penpot-installed-design-system.md`

That authority now specifies:

- live channel switching inside player
- episode switching inside player
- minimal OSD vs expanded OSD behavior
- chooser overlays for quality/audio/subtitle/source
- contextual back behavior from player states
- route/player ownership split so player does not become shell navigation
- player visual direction as Google TV-first with Apple TV restraint and
  Netflix/YouTube clarity influences

## Output

- player reference set locked
- player design gate locked in installed Markdown docs
- Phase 14 is unblocked

## Verification

- the installed design system contains the player gate rules
- execution-plan docs reference the repo-local player gate instead of pending
  Penpot work
- no player implementation code was started during this phase
