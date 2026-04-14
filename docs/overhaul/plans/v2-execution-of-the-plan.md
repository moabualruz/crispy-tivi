# V2 Execution-of-the-Plan

Status: Active
Date: 2026-04-11

## Purpose

This document is the plan for executing the v2 plan itself through the current
UI-first app baseline and then into the later full implementation track.

It defines:

- full phase order
- gate conditions
- active team lanes
- required evidence before advancing
- UI-first completion conditions
- later full-implementation phase entry conditions

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

Current branch state:

- complete

### Phase 8: live TV completion

Output:

- live TV channels complete end-to-end

Gate:

- live TV channels subview verified
- focus/activation rules verified

Current branch state:

- complete

### Phase 9: EPG / detail overlays completion

Output:

- guide behavior + EPG/detail overlays complete

Gate:

- live TV guide subview verified
- guide focus and activation rules verified

Current branch state:

- complete

### Phase 10: movies completion

Output:

- movie browsing + movie detail complete

Gate:

- mock player launch from movie detail verified

Current branch state:

- complete

### Phase 11: series completion

Output:

- series browsing + series detail complete

Gate:

- mock player launch from series episode selection verified

Current branch state:

- complete

### Phase 12: search completion

Output:

- search complete end-to-end

Gate:

- search -> canonical domain detail handoff verified

Current branch state:

- complete

### Phase 13: player pre-code design/reference gate

Output:

- player-specific references
- player subplan
- installed Markdown player gate

Gate:

- no player code starts before this gate is verified

Current branch state: complete

### Phase 14: player implementation

Output:

- retained player baseline complete for the UI-first app

Gate:

- player behavior/tests/flows verified

Current branch state: retained baseline complete

### Phase 15: UI-first app integration / hardening

Output:

- UI-first app integration complete
- UI-first evidence pack complete

Gate:

- UI-first completion criteria satisfied

Current branch state: complete

### Phase 16: player final UI/design completion

Current branch state: complete

### Phase 17: full implementation planning / execution reset

Current branch state: complete

### Phase 18+: full implementation track

- Phase 18 runtime contract reset: complete
- Phase 19 source/provider registry implementation: complete
- Phase 20 Live TV / EPG implementation: complete
- Phase 21 Media / Search implementation: complete
- Phase 22 playback backend integration: complete
- Phase 23 persistence, resume, and personalization: complete
- Phase 24 production hardening: complete
- Phase 25 full app runtime audit: complete
- Phase 26 demo/test gating and first-run truth: complete
- Phase 27 provider/controller wiring completion: complete
- Phase 28 screen and widget runtime audit closure: complete
- Phase 29 release-readiness audit and field validation: complete

Current state note:

- Phases 18 to 24 close the retained runtime foundation track
- they do not by themselves prove that every user-facing workflow is fully
  wired in real mode, correctly gated in demo/test mode, or manually validated
  under real sources
- next allowed lane: Phase 30

Post-Phase-29 note:

- because Phase 29 closed as `not ready`, the next valid work is the
  documented remediation track in
  `docs/overhaul/plans/v2-post-phase29-remediation-plan.md`
- Phase 30 provider persistence/import runtime is complete
- Phase 31 provider-driven runtime hydration is complete
- Phase 32 Rust-boundary correction is complete
- Phase 35 playback/diagnostics Rust migration plus release-readiness rerun is
  complete
- remediation outcome from Phase 35 remained `not ready`
- blocker ledger now lives in
  `docs/overhaul/plans/v2-phase35-release-blockers.md`
- follow-on cleanup track now lives in
  `docs/overhaul/plans/v2-post-phase35-release-cleanup-plan.md`
- Phase 38 shared XMLTV/catchup activation is complete
- Phase 39 release-warning cleanup is complete
- cleanup track outcome: ready
- next allowed lane: none inside the current track
- execution handoff for Phase 25 onward:
  - `docs/overhaul/plans/v2-phase25-audit-ledger.md`
  - `docs/overhaul/plans/v2-phase25-research-notes.md`
  - `docs/overhaul/plans/v2-phase25-repair-order.md`

Phase 15 verification evidence:

- `cargo test` in `rust/`
- `flutter analyze`
- `flutter test test/app/app_bootstrap_test.dart test/features/shell/asset_shell_bootstrap_repository_test.dart test/features/shell/asset_shell_content_repository_test.dart test/features/shell/asset_shell_contract_repository_test.dart test/features/shell/shell_models_test.dart test/features/shell/movie_view_test.dart test/features/shell/search_view_test.dart test/features/shell/shell_page_test.dart test/features/shell/shell_view_model_test.dart`
- `flutter test integration_test/main_test.dart -d linux`
- `app/flutter/tool/restore_linux_release_state.sh`
- `flutter build linux`
- `flutter build web`
- browser-driven web smoke on the built web app:
  - `.playwright-cli/phase15-final-web.png`

Phase 15 closure notes:

- final retained shell/player/settings/live/media/search integration is verified
- Linux release state is restored after Linux integration smoke
- no known blocking regressions remain in the current UI-first branch state

### Phase 16: player final UI/design completion

Output:

- final player visual/design completion
- final player control-language completion
- final player design evidence pack complete

Gate:

- player visuals, controls, OSD states, chooser language, and route-entry
  behavior are fully re-audited against the approved reference set and current
  requirements
- no remaining player design drift remains in app code, docs, or design HTML

Current branch state: complete

Phase 16 verification evidence:

- `flutter analyze`
- `flutter test test/features/shell/player_view_test.dart`
- `flutter build linux`
- `flutter build web`
- browser-driven preview evidence from:
  - `design/docs/player-mock-preview.html`
  - `.playwright-cli/phase16-player-preview.png`

### Phase 17: full implementation planning / execution reset

Output:

- full implementation plan replaces UI-first completion framing
- real data/playback/provider/domain implementation phases are explicitly
  defined

Gate:

- UI-first baseline is accepted as stable input
- remaining real-implementation scope is explicitly decomposed before product
  completion is discussed again

Current branch state: complete

Phase 17 output artifact:

- `docs/overhaul/plans/v2-full-implementation-plan.md`
- `docs/overhaul/plans/v2-implementation-reference-study.md`

Phase 17 follow-on phase order:

- Phase 18: runtime contract reset
- Phase 19: source/provider registry implementation
- Phase 20: Live TV and EPG implementation
- Phase 21: Media and Search implementation
- Phase 21 carries retained asset-backed Media/Search runtime snapshots in the
  data/domain boundary until provider-backed replacement lands
- Phase 22: playback backend integration
- Phase 23: persistence, resume, and personalization
- Phase 24: production hardening
- Phase 25: full app runtime audit
- Phase 26: demo/test gating and first-run truth
- Phase 27: provider/controller wiring completion
- Phase 28: screen and widget runtime audit closure
- Phase 29: release-readiness audit and field validation

Current branch state after follow-on start:

- Phase 18 complete
- Phase 19 complete
- Phase 20 complete
- Phase 21 complete
- Phase 22 complete
- Phase 23 complete
- Phase 24 complete
- Phase 25 complete
- Phase 26 complete
- Phase 27 complete
- Phase 28 complete
- Phase 29 complete
- next allowed lane: Phase 30

Runtime-foundation rule for the follow-on phases:

- Phase 18 onward must prefer the existing shared Rust crates in
  `rust/shared/crispy-*` for protocol and business responsibilities before
  inventing new app-local replacements
- Phase 18 onward must stay grounded in the local study repos under
  `for_study/`, especially:
  - `Megacubo` for setup/history/list-management expectations
  - `Hypnotix` for provider simplicity and type framing
  - `IPTVnator` for provider/data-source architecture, large-list handling, EPG
    strategy, and persisted favorites/recent-items expectations
- Phase 18 runtime-boundary work must expose stable Flutter repository
  interfaces first and keep temporary asset-backed implementations behind
  those interfaces until Rust-backed replacements are ready.
- Phase 18 closure must record the runtime replacement map for
  contract/content/bootstrap ownership in a phase doc.
- Phase 19 source/provider closure must record the retained source-registry
  replacement map and must route Settings-owned provider flows through the
  runtime source registry rather than legacy `ShellContent` source cards.
- Phase 20 live-TV closure must record the retained live-TV runtime boundary
  and must route browse groups, guide rows, and selected-detail state through
  that runtime path rather than heuristic group slicing or legacy
  `ShellContent` live-TV browse/guide data.
- Phase 21 media/search closure must record the retained media/search runtime
  boundary and must route active Media/Search behavior through that runtime
  path rather than legacy `ShellContent` movie/series/search fields.
- Phase 25 must produce a route/widget/workflow audit ledger for both real mode
  and explicit demo/test mode before later completion claims are credible.
- Phase 26 may not start until the Phase 25 repair-order artifact exists.
- Phase 26 must prove seeded/demo data is gated off the default boot path and
  that fresh installs land in a true zero-provider first-run flow.
- Phase 26 closure is recorded in
  `docs/overhaul/plans/v2-phase26-demo-test-gating.md`.
- Phase 27 must finish provider/controller ownership so setup/auth/import
  behavior is real, typed, validated, and runtime-backed rather than
  scaffolded.
- Phase 27 closure is recorded in
  `docs/overhaul/plans/v2-phase27-provider-controller-wiring.md`.
- Phase 28 must close the remaining screen/widget runtime-audit gaps and remove
  fallback shaping from presentation surfaces where retained runtime boundaries
  already exist.
- Phase 29 must manually validate real-source behavior and recheck release
  readiness after the audit-track fixes land.

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

## UI-first completion definition

The UI-first app baseline is complete only when all of the following are true:

- shell complete + verified
- onboarding/auth/import complete + verified
- settings complete + verified
- live TV complete + verified
- EPG/detail overlays complete + verified
- movies complete + verified
- series complete + verified
- search complete + verified
- player design gate complete + verified
- retained player baseline complete + verified
- UI-first integration evidence exists
- no known blocking regressions remain in the UI-first branch state

## Full-product completion definition

The v2 product is not complete until:

- the UI-first app baseline is complete
- Phase 16 player final UI/design completion is complete
- Phase 17 full implementation planning/execution reset is complete
- later real-implementation phases for providers, playback, persistence,
  onboarding/import/auth, production hardening, full-app audit, demo/test
  gating, provider/controller wiring, runtime-audit closure, and release
  validation are executed and verified
