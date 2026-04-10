# CrispyTivi Design-System Reboot Execution Plan

Date: 2026-04-10

## Official References

Research before and during implementation:

- Penpot user guide: https://help.penpot.app/user-guide/
- Penpot MCP repo/docs: https://github.com/penpot/penpot-mcp
- Penpot local MCP setup notes: https://community.penpot.app/t/self-hosted-open-source-design-system/10168/8
- Widgetbook docs: https://docs.widgetbook.io
- Widgetbook annotation API in local pub cache:
  `~/.pub-cache/hosted/pub.dev/widgetbook_annotation-*/lib/src/use_case.dart`

## Execution Phases

### Phase 1: Governance

1. Update `AGENTS.md` with design-system rules.
2. Create/refine local skills:
   - `.codex/skills/penpot-design-system/SKILL.md`
   - `.codex/skills/widgetbook-design-system/SKILL.md`
3. Keep requirements and this plan checked in under `.omx/plans/`.

Exit criteria:

- `AGENTS.md` contains durable rules.
- Skills include official-doc workflow, local MCP caveats, and verification.

### Phase 2: Penpot Reset

1. Use local MCP REPL to clear the active design-system page.
2. Rename undeletable stale pages with `ARCHIVE -` or `WIP Empty -`.
3. Verify active page is empty before rebuild.

Exit criteria:

- Active page has 0 boards.
- Old pages are explicitly non-authoritative.

### Phase 3: Widget Coverage Matrix

1. Scan Dart files for public/reusable widgets in:
   - `app/flutter/lib/core/widgets/`
   - `app/flutter/lib/core/navigation/`
   - `app/flutter/lib/features/*/presentation/widgets/`
   - `app/flutter/lib/features/*/presentation/screens/`
2. Generate `design/docs/widgetbook-coverage.md`.
3. For every widget, assign:
   - `direct-use-case`
   - `family-use-case`
   - `deferred-provider-fixture`
   - `deferred-runtime-platform`
   - `private-helper`
4. Include owner file, planned use-case path, Penpot link, and blocker.

Exit criteria:

- No unclassified widgets remain.
- Direct/family/deferred counts are summarized.

### Phase 4: Widgetbook Implementation

1. Keep runtime shell in `app/flutter/lib/widgetbook.dart`.
2. Organize annotated use cases by surface:
   - foundations
   - core widgets
   - feature widgets
   - player widgets
   - future files as coverage expands
3. Add one `@widgetbook.UseCase` per eligible widget or tight family.
4. Use fixture data and provider overrides where stable.
5. Update coverage matrix as use cases are added.

Exit criteria:

- Covered widgets have annotations and design links.
- Deferred widgets have concrete blocker text.
- Widgetbook build passes.

### Phase 5: Penpot Token and Asset Library

1. Create/update active token set `CrispyTivi`.
2. Populate:
   - color tokens
   - spacing tokens
   - radius tokens
   - any typography/elevation/motion tokens that exist in Flutter source
3. Upload checked-in brand assets from `app/flutter/assets/`.

Exit criteria:

- Penpot read-back shows active `CrispyTivi` token set and expected count.
- Asset board includes uploaded real repo assets.

### Phase 6: Penpot Components and Variants

1. Build editable component boards:
   - buttons
   - badges
   - chips
   - headers
   - surfaces
   - state widgets
   - skeletons
   - media cards
   - TV controls
   - feature widgets from direct Widgetbook coverage
2. Add variants/states:
   - default
   - focused
   - hover/pressed where meaningful
   - selected
   - disabled
   - loading
   - error/empty where applicable
3. Link each component board to Widgetbook use-case paths and Flutter owners.

Exit criteria:

- Penpot read-back shows expected component boards.
- No duplicate active board names.

### Phase 7: Penpot Patterns and Screens

1. Build editable pattern boards:
   - navigation shell
   - TV focus
   - EPG timeline
   - player OSD
   - media rails/cards
2. Build representative screen compositions using components:
   - Home
   - Live TV
   - Guide
   - Movies/Series
   - Settings
   - Multiview/Player
3. Use screenshots/goldens only as reference, not primary design.

Exit criteria:

- Patterns and screens are editable shapes.
- Boards are placed in a non-overlapping grid on active page.

### Phase 8: Verification and Iteration

Run:

```bash
dart format app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart
dart analyze app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart
scripts/design/check_design_tokens.sh
scripts/design/build_widgetbook.sh
```

Then Penpot read-back:

- active page
- token set
- board names/count
- asset images
- duplicate board names

Exit criteria:

- All checks pass or documented blocker exists.
- Result is recognizably a design system.

## Current Execution Start Point

Proceed from Phase 1 after this plan is updated.
