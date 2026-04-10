# CrispyTivi Design System

This folder is the repository-owned bridge between Penpot, Flutter design
tokens, and the Widgetbook component catalog.

## Surfaces

- `tokens/` - exported or hand-curated design token JSON.
- `assets/` - exported design assets that are safe to commit.
- `docs/` - design decisions, mapping notes, and agent handoff docs.

## Current Design System

- `docs/design-system.md` - current coverage and remaining gaps.
- `penpot/publish_editable_design_system.js` - Penpot MCP publisher payload
  that creates editable token, component, pattern, and representative screen
  boards in the local Penpot file.
- `penpot/publish_design_assets.py` - local Penpot MCP REPL publisher that
  uploads checked-in Flutter logo artwork into the design-system asset board.
- `scripts/design/generate_widgetbook_coverage.py` - regenerates the
  Widgetbook coverage matrix from Flutter widget/screen sources.

## Widgetbook Annotations

`app/flutter/lib/widgetbook.dart` uses official `@widgetbook.UseCase`
annotations from `widgetbook_annotation`. Use cases are split by widget family
under `app/flutter/lib/widgetbook/`; each cataloged widget has its own annotated
builder and Penpot design link.

## Source Of Truth

Flutter implementation tokens remain under:

- `app/flutter/lib/core/theme/`
- `app/flutter/lib/core/widgets/`

Penpot should mirror those tokens instead of inventing parallel names. If a
new value is needed, add it to Flutter tokens first, then export/update Penpot.

## Local Workflow

```bash
scripts/design/generate_widgetbook_coverage.py
scripts/design/check_design_tokens.sh
scripts/design/build_widgetbook.sh
scripts/design/serve_widgetbook.sh
```

Penpot token export is intentionally environment-driven so no access tokens or
file IDs are committed:

```bash
PENPOT_TOKENS_FILE=/path/to/export.json scripts/design/export_penpot_tokens.sh
```

or:

```bash
PENPOT_EXPORT_CMD='penpot-export --file "$PENPOT_FILE_ID"' \
  scripts/design/export_penpot_tokens.sh
```
