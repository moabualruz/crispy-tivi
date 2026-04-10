---
name: design-system
description: Use when changing CrispyTivi visual design, design tokens, Penpot assets, Widgetbook stories, component catalog coverage, or UI design-system docs.
---

# CrispyTivi Design System Skill

Use this workflow for visual design, reusable widgets, theme tokens, Penpot
handoff, and Widgetbook catalog changes.

## Ownership Rules

- Flutter implementation tokens are authoritative:
  - `app/flutter/lib/core/theme/`
  - `app/flutter/lib/core/widgets/`
- Penpot mirrors the checked-in Flutter tokens; do not invent parallel token
  names in Penpot or exported JSON.
- Prefer Locality of Behaviour over DRY. Keep component-specific behavior near
  the widget unless there is a repeated design-system primitive.
- No new visual token without first checking for an existing `Crispy*` token.
- No new UI dependency unless explicitly requested.

## Penpot Workflow

1. If Penpot MCP is available, inspect the relevant file/components before
   changing Flutter UI.
2. If token export is needed, run:

```bash
scripts/design/export_penpot_tokens.sh
```

3. If Penpot MCP is not configured, use checked-in exports under `design/` and
   state that Penpot was not available.

### Penpot Safety Rules

- Check the actual target Penpot URL/file, not a newly created local file, before
  claiming visual completion.
- Data read-back is necessary but not sufficient. Also capture a browser
  screenshot/snapshot and verify the active boards are visibly separated and not
  hidden under stale/orphan shapes.
- Penpot child shapes use page-absolute coordinates. Board-local drawing helpers
  must add `board.x` / `board.y` to every child shape and imported asset.
- Rebuilds must clear all active-page root children before drawing; otherwise
  old inventory shapes can remain on top of the new design-system boards.
- Use distinct board fills and large overview labels so the system remains
  readable at low Penpot zoom.

Expected MCP server command when configured:

```bash
npx @penpot/mcp@beta
```

## Flutter + Widgetbook Workflow

1. Read current tokens/widgets before editing.
2. Update Flutter tokens or widgets in the owning feature.
3. Add or update `app/flutter/lib/widgetbook.dart` use cases for visible
   component changes.
4. Run:

```bash
scripts/design/check_design_tokens.sh
scripts/design/build_widgetbook.sh
```

5. For behavior-bearing UI, run targeted Flutter tests or golden tests for the
   touched feature.

## Required Final Evidence

Report:

- Token changes, if any.
- Widgetbook use cases added/updated.
- Penpot source used: MCP, exported file, or unavailable.
- Commands run and results.
- Remaining visual or verification risks.
