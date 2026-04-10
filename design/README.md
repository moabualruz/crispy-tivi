# CrispyTivi Design System

This folder is the repository-owned bridge between Penpot, Flutter design
tokens, and the Widgetbook component catalog.

## Surfaces

- `tokens/` - exported or hand-curated design token JSON.
- `assets/` - exported design assets that are safe to commit.
- `docs/` - design decisions, mapping notes, and agent handoff docs.

## Source Of Truth

Flutter implementation tokens remain under:

- `app/flutter/lib/core/theme/`
- `app/flutter/lib/core/widgets/`

Penpot should mirror those tokens instead of inventing parallel names. If a
new value is needed, add it to Flutter tokens first, then export/update Penpot.

## Local Workflow

```bash
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
