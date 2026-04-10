# CrispyTivi Design-System Reboot Requirements

Date: 2026-04-10

## Problem Statement

The previous Penpot output was not an acceptable UI/UX design system. It was
mostly screenshots and bullet-point inventory text. The reboot must produce a
proper editable Penpot design-system artifact and matching Widgetbook catalog
coverage.

## User Requirements

1. Stop the broken Penpot direction.
2. Delete/reset all current Penpot noise.
3. Restart from documented requirements and a proper execution plan.
4. Research official docs before deciding implementation workflow.
5. Create local skills that encode how to do the work correctly.
6. Execute using those skills and tools.
7. Refine skills/tools as failures and API quirks are discovered.
8. Continue iterating until the output is a proper design system.

## Penpot Requirements

1. Penpot must be a real UI/UX design system, not a screenshot dump.
2. Penpot output must be editable shapes/components/patterns.
3. Screenshots/goldens are reference evidence only, never the primary artifact.
4. Penpot must use token sets in the Penpot token library.
5. Token names must mirror Flutter/check-in token names.
6. Penpot must use actual repo assets where available.
7. Penpot must include editable boards for:
   - foundations
   - colors
   - typography
   - spacing
   - radius
   - elevation/motion notes
   - components
   - component states
   - variants
   - navigation patterns
   - TV focus patterns
   - media-card patterns
   - EPG timeline pattern
   - player OSD pattern
   - representative screen compositions
   - brand assets
8. Components must be placed under correct sections.
9. Boards must be positioned so they are visible, non-overlapping, and not
   hidden behind token/foundation boards.
10. Components/patterns must include annotations/linkage:
    - Flutter widget/file owner
    - Widgetbook use case path
    - Penpot token names
    - asset source
    - reference/golden source when relevant
11. If local Penpot MCP cannot delete old pages, old pages must be clearly
    archived and the active design page must be unambiguous.

## Widgetbook Requirements

1. Widgetbook is required for this design-system work.
2. Use official `widgetbook_annotation`.
3. Use official `@widgetbook.UseCase` annotations.
4. Every relevant public/reusable UI widget in code must be handled.
5. Scope for widget coverage:
   - `app/flutter/lib/core/widgets/`
   - `app/flutter/lib/core/navigation/`
   - `app/flutter/lib/features/*/presentation/widgets/`
   - `app/flutter/lib/features/*/presentation/screens/`
6. Every widget must have one of:
   - `direct-use-case`: direct annotated Widgetbook use case
   - `family-use-case`: covered by a tight family use case
   - `deferred-provider-fixture`: needs provider overrides/fixtures first
   - `deferred-runtime-platform`: requires platform/video/window runtime
   - `private-helper`: private/non-reusable helper, covered by parent
7. No broad inventory/dashboard use case may substitute for component coverage.
8. Widgetbook use cases must be visual/interactive fixtures, not documentation
   cards.
9. Each use case must include a Penpot `designLink`.
10. Provider-heavy widgets need stable provider overrides or explicit deferral.
11. A checked-in widget coverage matrix is required.

## AGENTS.md Requirements

1. Add durable design-system rules to `AGENTS.md`.
2. Rules must enforce:
   - Penpot token sets/components/assets
   - editable Penpot artifacts
   - no screenshot/bulletpoint substitute
   - per-widget Widgetbook annotation decisions
   - design links
   - required verification

## Verification Requirements

1. Penpot read-back:
   - active page name
   - token set name/count
   - board names/count
   - asset count
   - no duplicate active board names
2. Widgetbook:
   - `dart format`
   - `dart analyze`
   - `scripts/design/build_widgetbook.sh`
3. Design tokens:
   - `scripts/design/check_design_tokens.sh`
4. Docs:
   - requirements and plan are checked in
   - coverage matrix is checked in
   - final report lists remaining deferred widgets

## Local Tool Constraints

1. Local Penpot MCP REPL endpoint is `http://localhost:4403/execute`.
2. Cross-page deletion/reparenting has proven unreliable.
3. Build one authoritative active design-system page.
4. Archive old pages if they cannot be deleted through MCP.
5. Avoid large base64 payloads through REPL; upload compressed assets only
   when needed.
