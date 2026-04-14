# V2 Reference Grounding Notes

Status: Active
Date: 2026-04-11

## Purpose

Record the concrete external visual references that must inform the redesign
pass, in addition to the conversation-history full spec.

## Reference folders

- `design/reference-images/tv-ui-2026/`
- `design/reference-images/tv-ui-2026-more/`
- `for_study/Megacubo`
- `for_study/hypnotix`
- `for_study/iptvnator`
- `for_study/player-ui-study/*`
- `rust/shared/crispy-*`

## Reference use

These references are not authority over the product spec, but they are the
mandatory grounding set for:

- visual composition, hierarchy, and chrome behavior
- provider/setup/runtime architecture expectations
- player and IPTV interaction patterns
- real implementation decomposition after the UI-first baseline

## Non-authority screenshot warning

The checked-in screenshots under `docs/screenshots/` show the legacy shipped app
shell and are not visual authority for v2 shell work. They may be useful only
for historical comparison or migration auditing.

If a legacy screenshot conflicts with:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. the live approved Penpot page
3. the reference sets above

the screenshot loses immediately.

## Current cues to apply

### Google TV

- content-first home layout
- top-level home/live/apps style navigation patterns
- settings and profile/settings access via utility/global-entry treatment
- contextual sheets and utility affordances that do not dominate the shell

### Apple TV

- premium widget treatment
- restrained depth and focus lift
- cleaner iconography / lighter chrome presence
- profile / account chooser patterns

### Netflix

- content rows dominate the page
- cinematic hero + row hierarchy
- player/info density should feel direct and media-led

### YouTube

- player OSD and info hierarchy should be examined as a reference for clarity

## Runtime grounding cues

### Megacubo

- setup wizard and list onboarding matter as real product flows
- continue-watching/history should be treated as real user features
- transmission/source switching must stay explicit in playback

### Hypnotix

- provider types should remain easy to understand
- live / movies / series framing should stay direct

### IPTVnator

- runtime architecture should stay provider/domain-sliced, not monolithic
- large live-channel surfaces need serious list/guide scaling strategy
- desktop-class persisted favorites/recent-items behavior should be explicit
- deterministic mock servers are valuable for provider/runtime tests

### Shared Rust crates

- runtime phases should use the existing `crispy-*` crates as the first-choice
  implementation foundation for protocol parsing, provider integration, EPG
  ingestion, catchup derivation, normalization, and diagnostics

## Hard rule

Do not produce new Penpot boards until the board content can be explained both
by:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. at least one concrete downloaded visual reference when the question is about
   composition or chrome behavior

## Player-specific future rule

When the project is ready to start player work:

- gather a fresh player-specific reference set first
- include Google TV, Apple TV, Netflix, and YouTube player/OSD/info examples
- update the player subplan from those references
- update the repo-local installed player gate before any player code starts
- if Penpot player boards are later recreated, they must be derived from the
  installed Markdown player gate rather than acting as a parallel authority
