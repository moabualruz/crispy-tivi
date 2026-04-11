# V2 Shell Design-System Plan

Status: Phase-1 active foundation baseline
Date: 2026-04-11

## Authoritative sources

- `docs/overhaul/plans/v2-conversation-history-full-spec.md`
- `design/docs/app-overhaul-design-system.md`
- `design/docs/design-system.md`
- `docs/overhaul/plans/v2-penpot-literal-checklist.md`
- `design/penpot/publish_app_overhaul_design_system.js`
- local references under `design/reference-images/`

## Installed approved design baseline

The active approved overhaul design is installed into the repo-local design
docs and token artifacts:

- installed design authority:
  `design/docs/penpot-installed-design-system.md`
- page id: `ec16cff3-941d-80ee-8007-d9645092a3ef`
- token set: `CrispyTivi vNext`
- token count: `25`

This manifest is the current design authority for the restart lane. Code does
not get to redefine it.

## Approved board set

The shell design-system is pinned to these fourteen approved boards:

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

These replace the earlier smaller reboot-era specimen set.

## Locked shell rules

- top navigation owns global and domain switching only
- side navigation owns current-domain local navigation and filters
- content pane remains the dominant active surface
- overlays sit above content instead of replacing navigation structure
- both left-origin and right-origin menu patterns exist
- both `32/68` and `36/64` shell splits exist
- RTL mirroring exists
- the player remains behind the explicit player design gate

## Restart implication

The reset path starts from this installed design baseline, not from Flutter or
Rust implementation state. If code disagrees with the pinned boards and rules,
the code is wrong until the user explicitly approves a design change.

## Verification

Verification must confirm all of the following before restart implementation
continues:

- installed design baseline matches
  `design/docs/penpot-installed-design-system.md`
- exactly fourteen approved overhaul boards exist
- no unexpected overhaul boards exist
- `CrispyTivi vNext` exists with `25` tokens
- Flutter token/theme surfaces analyze cleanly
- Linux target and web target both render the changed token/theme surfaces
- web verification includes a browser-rendered smoke capture

## Current state

Phase 1 remains the active foundation baseline and the current rebuild now
reintroduces the minimum Flutter token/theme surfaces from it:

- JSON overhaul tokens remain pinned in `design/tokens/crispy-overhaul.tokens.json`
- Flutter token surface exists at `app/flutter/lib/core/theme/crispy_overhaul_tokens.dart`
- Flutter theme surface exists at `app/flutter/lib/core/theme/theme.dart`
- phase completion still requires an explicit drift check against the installed
  design baseline and active v2 spec
