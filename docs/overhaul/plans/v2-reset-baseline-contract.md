# V2 Reset Baseline Contract

Status: Phase-0 complete
Date: 2026-04-11

## Purpose

Define the clean restart baseline so destructive cleanup can happen without
reopening design interpretation.

## Authority order

Reset and rebuild work must obey this order:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. live approved Penpot page locked by
   `design/penpot/publish_app_overhaul_design_system.js`
3. approved reference sets under `design/reference-images/`
4. `docs/overhaul/plans/v2-penpot-literal-checklist.md`
5. `docs/overhaul/plans/v2-tv-rewrite-execution-plan.md`
6. `AGENTS.md`

## Verified current design baseline

Verified on 2026-04-11 against the connected Penpot file:

- page id: `ec16cff3-941d-80ee-8007-d9645092a3ef`
- page name: `Page 1`
- approved overhaul boards: `14`
- token set: `CrispyTivi vNext`
- token count: `25`
- verifier status:
  `aligned-approved-current-design`

This means the design baseline is already pinned and does not need regeneration
from repo code.

## What is preserved

These surfaces are baseline authority and must survive any repo reset:

- `design/docs/`
- `design/penpot/`
- `design/reference-images/`
- `docs/overhaul/plans/`
- `AGENTS.md`

These surfaces are explicitly not visual authority for v2 shell decisions:

- `docs/screenshots/`
- older shipped-app screenshots or captures that show the legacy left-rail shell
- any old main-branch app screenshots or visual captures
- any derived mock that predates the pinned Penpot overhaul page

## What is disposable

Implementation drift is disposable when it conflicts with the pinned design or
the clean-branch v2 architecture rules.

Primary disposable categories:

- Flutter implementation scaffolds that guessed shell/layout structure
- Rust implementation scaffolds that started before approved shell contracts
- stale reboot docs that describe older Penpot artifact sets
- generated or exploratory code not backed by the approved plan stack

## Reset rules

- do not reset Penpot from code
- do not treat current Flutter or Rust structure as authoritative
- do not treat legacy repo screenshots as authoritative when they conflict with
  the live approved Penpot page or the conversation-history full spec
- do not treat old main-branch app visuals as authoritative at all
- do not carry forward old-app cues such as underline nav markers, pill-heavy
  chrome, or permanent right-side global `Back`/`Menu`
- do not reuse prior implementation structure after a reset request unless it is
  explicitly re-approved against the authority stack
- do not rebuild with god files, mixed-responsibility modules, or weak
  DDD/SOLID/LOB/DRY structure
- do not start shell implementation until repo state is reduced to a clean
  restart baseline
- do not perform destructive cleanup without a recoverable snapshot
- after cleanup, rebuild from the pinned Penpot boards and approved plans only

## Required reset sequence

1. verify the approved Penpot manifest
2. snapshot the dirty worktree to a recovery branch or archive commit
3. remove implementation drift that is not part of the clean restart baseline
4. keep only design authority, plan authority, and minimum build scaffolding
5. reintroduce implementation in phase order from
   `docs/overhaul/plans/v2-tv-rewrite-execution-plan.md`
6. before any completion claim, run Linux and web automated smoke verification
   targeted to the changed surfaces

## Exit criteria for phase-0 reset

- approved Penpot manifest still verifies
- repo authority docs are intact
- stale shell/design-system plan drift is removed
- destructive cleanup scope is explicit before execution
- restart can proceed without consulting old implementation for design answers

## Completion note

Phase 0 is complete for the current branch state:

- restart-invalid Flutter shell/theme/windowing code was removed
- restart-invalid Rust shell contract crates were removed
- baseline tracked placeholders were restored
- active shell/design-system and Widgetbook mapping docs were repinned
- the next allowed work starts at Phase 1, not Phase 4
