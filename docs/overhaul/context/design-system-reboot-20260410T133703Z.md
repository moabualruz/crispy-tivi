# Ralph Context Snapshot: Design-System Reboot

Timestamp: 2026-04-10T13:37:03Z

## Task Statement

Execute `$plan` with `$ralph` and `$caveman` for CrispyTivi design-system
reboot. User requires complete planning, local skills, AGENTS rules, Widgetbook
coverage matrix, proper Penpot design-system rebuild, and verification.

## Desired Outcome

- Real editable Penpot UI/UX design system, not screenshot/bullet inventory.
- Official Widgetbook `@UseCase` annotations.
- Coverage matrix for every relevant Flutter UI widget.
- Durable skills and AGENTS rules.
- Verified Widgetbook build, token checks, Dart analyze, and Penpot read-back.

## Known Facts / Evidence

- Local Penpot MCP REPL endpoint works: `http://localhost:4403/execute`.
- Local Penpot cross-page deletion/reparenting unreliable; build on one active
  page and archive old pages.
- Active Penpot page was reset to `CrispyTivi Clean Start` with 0 boards.
- Penpot token set `CrispyTivi` exists and has 22 tokens after publish.
- Current Widgetbook shell is `app/flutter/lib/widgetbook.dart`.
- Use-case files exist under `app/flutter/lib/widgetbook/`.
- Existing generated widget coverage matrix currently reports 609 UI classes.

## Constraints

- Flutter tokens authoritative:
  - `app/flutter/lib/core/theme/`
  - `design/tokens/crispy.tokens.json`
- Penpot token names must mirror Flutter/check-in token names.
- Widgetbook use cases must be per widget or tight family.
- No broad inventory handlers.
- Screenshots/goldens are evidence only.
- Caveman mode for user-facing progress/final.

## Unknowns / Open Questions

- Which deferred provider-heavy widgets can be safely fixture-backed next.
- Whether Penpot component/variant API is reliable enough for true library
  components, beyond editable variant boards.

## Likely Codebase Touchpoints

- `AGENTS.md`
- `.codex/skills/penpot-design-system/SKILL.md`
- `.codex/skills/widgetbook-design-system/SKILL.md`
- `docs/overhaul/plans/design-system-reboot-requirements.md`
- `docs/overhaul/plans/design-system-reboot-execution-plan.md`
- `design/docs/widgetbook-coverage.md`
- `design/docs/design-system.md`
- `design/penpot/publish_editable_design_system.js`
- `design/penpot/publish_design_assets.py`
- `app/flutter/lib/widgetbook.dart`
- `app/flutter/lib/widgetbook/*.dart`
- `app/flutter/pubspec.yaml`
- `app/flutter/pubspec.lock`
