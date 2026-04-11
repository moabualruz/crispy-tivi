# CrispyTivi Design System

This document records the active restart-lane design baseline.

## Authority

The current design authority order is:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. live approved Penpot manifest locked by
   `design/penpot/publish_app_overhaul_design_system.js`
3. `design/docs/app-overhaul-design-system.md`
4. `docs/overhaul/plans/v2-shell-design-system-plan.md`
5. `AGENTS.md`

Flutter implementation does not redefine this baseline. Penpot is the visual
source of truth for the restart lane. A passing build does not override this:
if rendered UI, composition, or focus treatment drifts from the approved
Penpot boards or active v2 spec, the implementation is incorrect and must be
fixed before a phase can complete.

## Approved Penpot baseline

Verified active baseline:

- page id: `ec16cff3-941d-80ee-8007-d9645092a3ef`
- page name: `Page 1`
- token set: `CrispyTivi vNext`
- token count: `25`
- approved overhaul boards: `14`
- verifier status:
  `aligned-approved-current-design`

Approved boards:

1. `FOUNDATION - vNext Tokens`
2. `FOUNDATION - Layout and Windowing`
3. `COMPONENT - Navigation and Focus Controls`
4. `COMPONENT - Surfaces and Widget Feel`
5. `SCREEN - Home Shell`
6. `SCREEN - Settings and Sources Flow`
7. `SCREEN - Live TV Channels`
8. `SCREEN - Live TV Guide`
9. `SCREEN - Media Browse and Detail`
10. `SCREEN - Search and Handoff`
11. `FEATURE - Source Selection and Health`
12. `FEATURE - Favorites, History, and Recommendations`
13. `FEATURE - Mock Player and Full Player Gate`
14. `PATTERN - Left and Right Menus`

## Token source surfaces

The overhaul token family must remain aligned across:

- JSON: `design/tokens/crispy-overhaul.tokens.json`
- Penpot token set: `CrispyTivi vNext`
- Flutter token source when reintroduced in implementation

Current JSON token families:

- surface
- accent
- semantic
- text
- spacing
- radius
- motion

## Restart rule

This design-system document is intentionally restart-lane specific. Older
editable design-system inventory/runtime notes are no longer authoritative for
v2 shell work.

## Widgetbook note

Widgetbook runtime is not currently present on the clean restart baseline. The
active Widgetbook role is planning/specimen mapping through:

- `docs/overhaul/plans/v2-widgetbook-shell-specimens.md`
- `docs/overhaul/plans/v2-widgetbook-penpot-shell-map.md`
