# V2 Drift Audit

Status: Active authority note
Date: 2026-04-11

## Root cause

The drift did not come from one bad file. It came from a weak execution rule:

1. shell implementation was allowed to satisfy structure and navigation without
   proving board-faithful visual composition
2. phase completion language treated passing analyze/tests as sufficient proof
3. planning docs described route intent but did not make visual mismatch a hard
   blocker
4. generic shell scaffolding was allowed to stand in for approved Penpot screen
   design
5. legacy repo screenshots were left in the workspace without being explicitly
   demoted, so they could silently reintroduce the old left-rail shell model

## Mandatory correction

From this point forward:

1. Penpot plus the active v2 spec remain the visual and behavioral authority
2. every phase must include an explicit drift check against those sources
3. any mismatch or missing requirement blocks phase completion
4. implementation evidence must include design-faithful composition, not only
   runtime correctness
5. legacy screenshots must be treated as historical evidence only unless the
   user explicitly re-approves them as authority

## Impact on phases 1 to 4

- Phase 1 must prove token and foundation alignment, not only token presence.
- Phase 2 must act as a literal composition contract for screen work, not as a
  loose planning note.
- Phase 3 must constrain focus, back, menu, and shell ownership strongly enough
  that generic shell rendering cannot pass.
- Phase 4 is invalid if the rendered shell is navigable but still visually
  inconsistent with the approved Penpot boards and active screen intent.
