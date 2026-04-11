# V2 Skill Routing Plan

Status: Completed
Date: 2026-04-11

## Purpose

Define the best skills to use across the **entire v2 execution lifecycle**
and assign them explicitly to the leader and each lane.

## Global rule

Every agent and every team member:

1. follows `AGENTS.md` exactly
2. uses the lightest skill that still preserves correctness
3. does not improvise a different workflow when a matching skill already exists

## Best skills by top-level purpose

### Leader / orchestrator

Primary skills:

- `$autopilot`
- `$team`
- `$ralph`
- `$ultrawork`
- `$ralplan`
- `$plan`
- `$cancel`
- `$note`
- `$trace`

Why:

- `autopilot` = lifecycle owner across phases
- `team` = coordinated multi-lane execution
- `ralph` = persistent single-owner completion loops
- `ultrawork` = high-throughput independent execution inside a phase
- `ralplan` / `plan` = planning and re-planning
- `cancel` = clean mode shutdown
- `note` / `trace` = state and execution visibility

### Design lane

Primary skills:

- `$design-system`
- `$penpot-design-system`
- `$widgetbook-design-system`

Why:

- `design-system` = Flutter tokens/widgets + visual system workflow
- `penpot-design-system` = Penpot reset/publish/verification workflow
- `widgetbook-design-system` = Widgetbook design-system coverage

### Flutter shell / product lane

Primary skills:

- `$ralph`
- `$ultrawork`
- `$tdd`
- `$build-fix`

Why:

- `ralph` = persistent completion loop for concrete implementation slices
- `ultrawork` = parallel slice execution when write scopes are disjoint
- `tdd` = test-first flow for shell/windowing/focus behavior
- `build-fix` = tight build/type-error resolution

### Rust contracts / domain lane

Primary skills:

- `$ralph`
- `$ultrawork`
- `$tdd`
- `$build-fix`

Why:

- same persistent + parallel + test-first + build-fix loop, but applied to Rust/domain work

### Verification / quality lane

Primary skills:

- `$code-review`
- `$security-review`
- `$ralph`

Why:

- `code-review` = broad quality review
- `security-review` = security-specific pass
- `ralph` = persistent verify/fix loop where needed

## Skill usage by full product phase

### Phase 0: reset and re-ground

- leader: `$autopilot`, `$note`
- planning support: `$plan` or `$ralplan`

### Phase 1: overhaul design-system foundations

- leader: `$autopilot`
- design lane: `$design-system` + `$penpot-design-system`
- if Widgetbook scope starts: `$widgetbook-design-system`

### Phase 2: Widgetbook and shell design planning

- leader: `$autopilot`
- planning lane: `$ralplan`
- design lane: `$design-system` + `$penpot-design-system` + `$widgetbook-design-system`

### Phase 3: shell IA / focus / navigation planning

- leader: `$autopilot`
- planning lane: `$ralplan`
- design lane: `$design-system`

### Phase 4: shell implementation

- leader: `$autopilot` + `$team`
- Flutter lane: `$ralph` + `$tdd`
- parallel implementation support: `$ultrawork`
- build repair when needed: `$build-fix`

### Phase 5: technical contracts

- leader: `$autopilot` + `$team`
- Rust lane: `$ralph` + `$tdd`
- parallel support: `$ultrawork`
- build repair when needed: `$build-fix`

### Vertical phases: onboarding/auth/import, settings, live TV, EPG, movies, series, search

- leader: `$autopilot` + `$team`
- active implementation lanes: `$ralph` + `$tdd`
- parallel side lanes where safe: `$ultrawork`
- design updates when needed: `$design-system`, `$penpot-design-system`, `$widgetbook-design-system`

### Player pre-code design gate

- leader: `$autopilot` + `$ralplan`
- design lane: `$design-system` + `$penpot-design-system` + `$widgetbook-design-system`

### Player implementation

- leader: `$autopilot` + `$team`
- active lanes: `$ralph` + `$tdd`
- parallel side lanes where safe: `$ultrawork`
- design lane remains active

### Final integration / completion hardening

- leader: `$autopilot`
- quality lane: `$code-review` + `$security-review`
- fix/verify loops: `$ralph`

## Recommended skill prompts for spawned lanes

When delegating, the leader should explicitly tell workers which skills apply.

Examples:

- Design worker:
  - \"Follow AGENTS.md exactly. Use `$design-system` and `$penpot-design-system`.\"\n
- Widgetbook worker:
  - \"Follow AGENTS.md exactly. Use `$widgetbook-design-system`.\"\n
- Flutter implementation worker:
  - \"Follow AGENTS.md exactly. Use `$ralph` and `$tdd`; use `$build-fix` only if needed.\"\n
- Rust implementation worker:
  - \"Follow AGENTS.md exactly. Use `$ralph` and `$tdd`; use `$build-fix` only if needed.\"\n
- Verification worker:
  - \"Follow AGENTS.md exactly. Use `$code-review` and `$security-review` after fresh verification evidence.\"\n

## Conflict-free skill rule

Use `team` / `ultrawork` only when the write scopes are disjoint.

If write scopes overlap:

- keep one owner on `ralph`
- run other lanes as read-only review/planning/verification support
