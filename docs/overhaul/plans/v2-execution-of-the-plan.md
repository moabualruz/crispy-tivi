# V2 Execution-of-the-Plan

Status: Active
Date: 2026-04-11

## Purpose

This document is the plan for executing the v2 plan itself **through the final
finished product**.

It defines:

- full phase order
- gate conditions
- active team lanes
- required evidence before advancing
- final completion conditions

## Active authority stack

Execution must obey, in this order:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. `AGENTS.md`
3. active v2 plan docs under `docs/overhaul/plans/`
4. active reference-grounding notes and local reference-image sets
5. `docs/overhaul/plans/v2-skill-routing-plan.md`

## Full execution loop

For every phase:

1. confirm authority and phase inputs
2. confirm previous phase gate is complete
3. activate the minimal team needed
4. execute the whole phase in one shot
5. run a drift check against Penpot, the active spec, and active requirements
6. gather fresh evidence
7. record phase completion + handoff
8. only then move forward

## Full phase order

### Phase 0: reset and re-ground

Output:

- clean repo/design baseline
- authority confirmed
- restart/confusion docs updated

Gate:

- baseline verified
- premature implementation removed or archived

### Phase 1: overhaul design-system foundations

Output:

- Flutter overhaul token source
- JSON token parity
- Penpot overhaul artifacts

Gate:

- Penpot publish/read-back verified
- token evidence verified

### Phase 2: Widgetbook and shell design planning

Output:

- shell design-system plan
- widgetbook/penpot shell map
- shell visual intent
- widgetbook shell specimen list

Gate:

- shell visual plan is explicit

### Phase 3: shell IA / focus / navigation planning

Output:

- shell IA spec
- focus map spec
- back/menu rules
- component focus contracts

Gate:

- no route lacks IA/focus definition

### Phase 4: shell implementation

Output:

- shell implementation
- shell tests/integration evidence

Gate:

- shell implementation verified
- shell visuals verified against the approved Penpot boards and route intent
- phase-4 kickoff explicitly reactivated after reset

### Phase 5: technical contracts and shared support

Output:

- technical contracts
- Rust/FFI/shared infrastructure where required by approved shell

Gate:

- Rust/domain/FFI evidence verified

### Phase 6: onboarding/auth/import completion

Output:

- onboarding/auth/import complete end-to-end

Gate:

- source wizard entry/back safety verified

Current branch state:

- complete

### Phase 7: settings completion

Output:

- settings complete end-to-end

Gate:

- settings top-level group navigation verified
- settings search/deep leaf behavior verified

### Phase 8: live TV completion

Output:

- live TV channels complete end-to-end

Gate:

- live TV channels subview verified
- focus/activation rules verified

### Phase 9: EPG / detail overlays completion

Output:

- guide behavior + EPG/detail overlays complete

Gate:

- live TV guide subview verified
- guide focus and activation rules verified

### Phase 10: movies completion

Output:

- movie browsing + movie detail complete

Gate:

- mock player launch from movie detail verified

### Phase 11: series completion

Output:

- series browsing + series detail complete

Gate:

- mock player launch from series episode selection verified

### Phase 12: search completion

Output:

- search complete end-to-end

Gate:

- search -> canonical domain detail handoff verified

### Phase 13: player pre-code design/reference gate

Output:

- player-specific references
- player subplan
- Penpot player boards

Gate:

- no player code starts before this gate is verified

### Phase 14: player implementation

Output:

- player complete end-to-end

Gate:

- player behavior/tests/flows verified

### Phase 15: final integration / completion hardening

Output:

- final product integration complete
- final evidence pack complete

Gate:

- full-product completion criteria satisfied

## Vertical execution rule

One vertical must be completed and verified before the next vertical starts.

Vertical order:

1. onboarding/auth/import
2. settings
3. live TV
4. EPG / detail overlays
5. movies
6. series
7. search
8. player

## Evidence required at every phase

- exact changed artifacts
- exact commands run
- exact result summary
- exact drift/gap check result
- unresolved risks if any

## Anti-drift rule

No phase may complete on runtime correctness alone. If the rendered result,
phase output, or supporting docs drift from the approved Penpot design, active
v2 spec, or current user requirements, that drift must be fixed before the
phase may be recorded as complete.

## Team activation matrix

| Phase | Leader | Design | Flutter | Rust | Verify |
|---|---|---|---|---|---|
| 0 | yes | optional | no | no | optional |
| 1 | yes | yes | optional | no | yes |
| 2 | yes | yes | no | no | optional |
| 3 | yes | yes | optional | optional | optional |
| 4 | yes | yes | yes | optional | yes |
| 5 | yes | optional | no | yes | yes |
| 6 | yes | yes | yes | yes | yes |
| 7 | yes | yes | yes | yes | yes |
| 8 | yes | yes | yes | yes | yes |
| 9 | yes | yes | yes | yes | yes |
| 10 | yes | yes | yes | yes | yes |
| 11 | yes | yes | yes | yes | yes |
| 12 | yes | yes | yes | yes | yes |
| 13 | yes | yes | no | no | yes |
| 14 | yes | yes | yes | yes | yes |
| 15 | yes | optional | yes | yes | yes |

## Anti-drift rules

1. Do not treat scaffolds as adherence.
2. Do not treat design text as complete until Penpot/specimen evidence exists.
3. Do not let implementation outrun design/planning gates.
4. Do not let one lane silently redefine authority.
5. Every spawned lane follows `AGENTS.md`.
6. Player remains blocked until the player pre-code design gate is complete.

## Full-product completion definition

The v2 product is not complete until all of the following are true:

- shell complete + verified
- onboarding/auth/import complete + verified
- settings complete + verified
- live TV complete + verified
- EPG/detail overlays complete + verified
- movies complete + verified
- series complete + verified
- search complete + verified
- player design gate complete + verified
- player complete + verified
- final integration evidence exists
- no known blocking regressions remain
