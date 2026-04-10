# PRD: CrispyTivi Design-System Reboot

## Objective

Create a proper, repeatable CrispyTivi design-system workflow and artifacts:
Penpot editable design system, Widgetbook per-widget annotations, coverage
matrix, durable skills, AGENTS rules, and verification.

## Requirements

1. Reset current broken Penpot output.
2. Research official Penpot and Widgetbook docs before workflow decisions.
3. Maintain requirements and execution plan under `.omx/plans/`.
4. Create local skills for Penpot and Widgetbook workflows.
5. Update `AGENTS.md` with durable design-system rules.
6. Generate and maintain widget coverage matrix for all relevant UI widgets.
7. Add direct Widgetbook annotations for eligible widgets.
8. Document family coverage or deferral for all remaining widgets.
9. Populate real Penpot token set `CrispyTivi`.
10. Upload real repo brand assets to Penpot.
11. Build editable Penpot foundations/components/patterns/screens.
12. Verify with Dart, Widgetbook, token checks, and Penpot read-back.

## User Stories

### US-001: Requirements and Rules

As a future agent, I need requirements, plan, AGENTS rules, and skills so I can
continue design-system work without repeating prior mistakes.

Acceptance criteria:

- `.omx/plans/design-system-reboot-requirements.md` exists and includes every
  user requirement.
- `.omx/plans/design-system-reboot-execution-plan.md` exists and sequences work.
- `AGENTS.md` contains design-system rules.
- Penpot and Widgetbook skills exist.

### US-002: Widgetbook Coverage Matrix

As a maintainer, I need every UI widget classified so coverage gaps are explicit.

Acceptance criteria:

- `design/docs/widgetbook-coverage.md` exists.
- Matrix scans core widgets, core navigation, feature presentation widgets, and
  feature presentation screens.
- No `unclassified` widgets remain.
- Each row has owner file, widget name, decision, use case/family, reason.

### US-003: Widgetbook Annotated Use Cases

As a designer/developer, I need per-widget annotated use cases for stable
components.

Acceptance criteria:

- `widgetbook_annotation` is direct dependency.
- Use cases use `@widgetbook.UseCase`.
- Each direct use case has `designLink`.
- No broad inventory use-case substitutes for components.
- Widgetbook builds.

### US-004: Penpot Editable Design System

As a designer, I need editable Penpot tokens/components/patterns/screens.

Acceptance criteria:

- Active Penpot design page is unambiguous.
- `CrispyTivi` token set is active and populated.
- Brand assets uploaded from repo.
- Editable boards exist for foundations, components, patterns, screens, feature
  widgets, player widgets, and assets.
- No duplicate active board names.
- Screenshots/goldens are not primary design artifacts.

## Non-Goals

- Pixel-perfect redesign of every screen.
- Direct Widgetbook coverage for provider-heavy widgets without stable fixtures.
- Manual deletion of old Penpot pages through UI.

## Verification

- `dart format app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart`
- `dart analyze app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart`
- `scripts/design/check_design_tokens.sh`
- `scripts/design/build_widgetbook.sh`
- Penpot REPL read-back for token set, board count, duplicate count, assets.

