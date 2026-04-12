# V2 Reference Grounding Notes

Status: Active
Date: 2026-04-11

## Purpose

Record the concrete external visual references that must inform the redesign
pass, in addition to the conversation-history full spec.

## Reference folders

- `design/reference-images/tv-ui-2026/`
- `design/reference-images/tv-ui-2026-more/`

## Reference use

These references are not authority over the product spec, but they are the
mandatory grounding set for visual composition, hierarchy, and chrome behavior.

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
