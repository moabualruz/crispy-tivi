# Agent Workflow

Use this workflow when changing visual language, design tokens, reusable UI
components, or Widgetbook coverage.

1. Read the active project guidance in `AGENTS.md`.
2. Check the approved design docs in `design/docs/`.
3. Reuse existing Flutter tokens and shared widgets before adding new ones.
4. Verify the relevant Penpot page or exported design evidence before editing UI.
5. Compare the rendered UI and the active plan against the approved design and requirements before and after the change.
6. Treat any visual mismatch, structural drift, or missing requirement as a blocker. Fix it before calling the work complete.
7. Update Flutter tokens, widgets, and supporting docs together.
8. Run the relevant checks before claiming completion.

Recommended checks:

```bash
scripts/design/check_design_tokens.sh
scripts/design/build_widgetbook.sh
```

For behavior-bearing UI, also run the targeted feature, golden, or integration
tests that cover the touched surfaces.
