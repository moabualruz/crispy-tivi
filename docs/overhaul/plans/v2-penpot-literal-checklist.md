# V2 Penpot Literal Build Checklist

Status: Active
Authority: docs/overhaul/plans/v2-conversation-history-full-spec.md

## Reset precondition
- Penpot current page root children = 0
- Token set `CrispyTivi vNext` absent before rebuild
- No prior overhaul boards remain

## Required board groups
1. Foundation tokens
2. Layout and windowing
3. Navigation and focus controls
4. Surfaces and widget feel
5. Home shell
6. Settings and Sources flow
7. Live TV channels
8. Live TV guide
9. Media browse and detail
10. Search and handoff
11. Source selection and health
12. Favorites / Continue Watching / Recommendations
13. Mock Player and Full Player Gate
14. Left and Right Menus

## Mandatory content constraints
- Top navigation owns global/domain switching + global entry points only
- Side panel owns current-domain local navigation, filters, categories, settings sections, wizard steps
- Content pane owns dominant active surface
- Overlays sit above content and do not replace navigation
- Channels flow is replacement-flow, not simultaneous category+channel sidebars
- Settings is utility/global entry, not dominant primary top-nav strip
- Wizards are visible designed surfaces
- Both left-origin and right-origin menu patterns exist
- Both 32/68 and 36/64 layout variants exist
- RTL mirroring exists
- Player is not treated as a generic selectable shell view
- Mock player and player gate are shown as gate/rules, not final player UI

## Reference grounding
Use local references in:
- design/reference-images/tv-ui-2026/
- design/reference-images/tv-ui-2026-more/

Do not introduce visual language that cannot be justified by the full spec plus those references.
Do not use `docs/screenshots/` or any old main-branch app screenshots as
design input.
Do not reintroduce old-app underline nav cues, permanent top-bar `Back`/`Menu`,
or pill-heavy shell chrome unless Penpot explicitly shows them.
