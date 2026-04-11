# PRD: CrispyTivi v2 TV Rewrite

Status: Active
Date: 2026-04-11

## Authoritative sources

The overhaul design and shell direction must be taken from these sources first:

- `docs/overhaul/plans/v2-conversation-history-full-spec.md`
- live approved Penpot page locked by
  `design/penpot/publish_app_overhaul_design_system.js`
- `design/docs/app-overhaul-design-system.md`
- `design/docs/design-system.md`
- local visual reference sets under:
  - `design/reference-images/tv-ui-2026/`
  - `design/reference-images/tv-ui-2026-more/`

Implementation must not invent or reinterpret visual direction ahead of those
sources. If any checked-in project doc conflicts with the conversation-history
full spec, the conversation-history full spec wins for this v2 lane until the
user changes it.

Legacy repo screenshots are not authority for shell structure because they show
the old permanent-left-rail app shell, which conflicts with the current v2
planning lane.

## Restart rule

This effort is restarted from a clean baseline because previous work began
implementation before design-system alignment was actually established.

That reset has now been executed at the repo level. Deleted restart code is not
part of the product baseline and must not be consulted as design authority.

## Required order of work

1. Read and ground against the overhaul design docs.
2. Establish overhaul design-system foundations in Penpot, JSON, and Flutter
   tokens.
3. Define Widgetbook specimen coverage for the shell.
4. Define shell IA, focus, and navigation from the approved design direction.
5. Only then begin shell implementation.
6. Only after shell direction is approved begin technical contracts and deeper
   app work.

## Non-negotiable shell rules

- global/domain navigation belongs on the top bar
- side panel is current-domain local navigation only
- content pane is the active surface
- overlays are separate modal flows above content
- focus must be obvious from across a room
- generic Material scaffolds do not count as progress
- fake-scroll/windowed primitives are mandatory on every screen
- scale-not-reflow TV layout is mandatory

## Architecture rules

- Flutter: View/ViewModel only
- Rust: controller/business/domain orchestration only
- avoid large aggregator files and sprawling `mod.rs` / barrel surfaces
- prefer narrow ownership and locality of behavior

## Delivery sequence

1. Design-system foundations
2. Widgetbook + Penpot shell planning
3. Shell IA/focus/navigation planning
4. Shell implementation
5. Technical contracts where needed by the approved shell
6. Verticals later
7. Player pre-code design/reference gate
8. Player last
