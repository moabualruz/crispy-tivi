# Agent Design-System Workflow

Use this workflow when changing visual language, design tokens, reusable UI
components, or Widgetbook stories.

1. Read Flutter tokens in `app/flutter/lib/core/theme/`.
2. Check existing reusable widgets in `app/flutter/lib/core/widgets/`.
3. Reuse existing tokens before adding new ones.
4. If Penpot MCP is available, inspect the matching design file/components.
5. Update Flutter tokens/widgets.
6. Add or update `app/flutter/lib/widgetbook.dart` use cases.
7. Run:

```bash
scripts/design/check_design_tokens.sh
scripts/design/build_widgetbook.sh
```

For behavior-bearing UI, also run the feature tests or golden tests that cover
the touched widgets.

Do not treat Penpot exports as authoritative when they conflict with checked-in
Flutter tokens. Resolve the conflict explicitly and update both surfaces.
