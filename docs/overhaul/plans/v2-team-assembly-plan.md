# V2 Team Assembly Plan

Status: Active
Date: 2026-04-11

## Purpose

Define how the team should be assembled to execute the UI-first app baseline
and then the later full implementation track, not only the opening phases.

## Global rule

Every spawned agent and every team lane must follow `AGENTS.md` exactly.

That means especially:

- Flutter = View/ViewModel only
- Rust = controller/business/domain orchestration only
- no provider-native leakage into Flutter
- no implementation before required planning/design gates are complete
- no large aggregator/barrel/mod drift unless explicitly justified
- every lane should be told the specific skills it is expected to use

## Core lanes

### 1. Leader / orchestration lane

Owns:

- active authority/source of truth
- phase gate enforcement
- handoff decisions
- integration and stop decisions

Recommended roles:

- `planner`
- `architect`

### 2. Design / reference lane

Owns:

- Penpot artifacts
- Widgetbook/specimen planning
- visual/reference grounding
- route and vertical visual intent

Recommended roles:

- `designer`
- `writer`

### 3. Flutter product lane

Owns:

- shell and vertical UI implementation
- windowed primitives
- focus/runtime behavior
- view-only presentation mapping

Recommended roles:

- `executor`
- `test-engineer`

### 4. Rust domain/contracts lane

Owns:

- domain contracts
- FFI shapes
- source/media/search/playable logic
- provider translation

Recommended roles:

- `architect`
- `executor`

### 5. Verification lane

Owns:

- analyze/test/integration evidence
- regression proof
- completion proof

Recommended roles:

- `verifier`
- `test-engineer`

## Phase staffing by full product lifecycle

### Restart / design gate phases

#### Phase 0: reset and re-ground

- leader
- optional verifier

#### Phase 1: overhaul design-system foundations

- leader
- design lane
- verifier lane

#### Phase 2: Widgetbook and shell design planning

- leader
- design lane
- writer/doc support

#### Phase 3: shell IA / focus / navigation planning

- leader
- design lane
- architect/planner support

### Implementation phases

#### Phase 4: shell implementation

- leader
- design lane
- Flutter product lane
- verifier lane

#### Phase 5: technical contracts and support infrastructure

- leader
- Rust domain/contracts lane
- verifier lane

### Vertical product phases

Post-Phase-6 parallelization rule:

- parallel vertical/domain execution is allowed only after Phase 6 is complete
- preferred staffing is one phase orchestrator per independent domain/module
  phase lane
- shared contract/theme/test/doc integration files stay leader-owned unless
  explicitly reassigned
- no overlapping write scopes between active workers
- every parallel lane still follows the full authority stack and AGENTS rules
- each phase orchestrator owns the whole phase to closure: audit,
  implementation, drift recheck, verification, and doc closure
- do not split a single phase into partial orchestrators that hand off an
  unfinished phase as if it were complete

#### Phase 6: onboarding/auth/import flows

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

#### Phase 7: settings completion

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

#### Phase 8: live TV completion

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

#### Phase 9: EPG / detail overlays completion

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

#### Phase 10: movies completion

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane
- complete

#### Phase 11: series completion

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane
- complete

#### Phase 12: search completion

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

### Player-specific phases

#### Phase 13: player pre-code design/reference gate

- leader
- design lane
- verifier lane

Phase 13 closes only when the repo-local player gate is complete and verified in
installed Markdown docs. Recreated Penpot player boards are optional follow-on
artifacts, not the primary authority.

#### Phase 14: player implementation

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

### UI-first integration phase

#### Phase 15: UI-first app integration / hardening

- leader
- Flutter lane
- Rust lane
- verifier lane
- design lane only if final visual corrections are still required

Current branch state: complete

Required evidence recorded:

- Rust tests green
- Flutter analyze green
- retained-shell Flutter tests green
- Linux integration smoke green
- Linux release state restored after integration smoke
- Linux release build green
- web build green
- browser-driven web smoke evidence captured

### Post-UI-first phases

#### Phase 16: player final UI/design completion

- leader
- design lane
- Flutter lane
- verifier lane

Current branch state: complete

#### Phase 17: full implementation planning / execution reset

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

Current branch state: complete

Follow-on implementation phases after Phase 17:

- Phase 18 runtime contract reset
- Phase 19 source/provider registry implementation
- Phase 20 Live TV and EPG implementation
- Phase 21 Media and Search implementation
- Phase 21 carries retained asset-backed Media/Search runtime snapshots in the
  data/domain boundary until provider-backed replacement lands
- Phase 22 playback backend integration
- Phase 23 persistence, resume, and personalization
- Phase 24 production hardening
- Phase 25 full app runtime audit
- Phase 26 demo/test gating and first-run truth
- Phase 27 provider/controller wiring completion
- Phase 28 screen and widget runtime audit closure
- Phase 29 release-readiness audit and field validation

Current follow-on state:

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

Post-Phase-29 remediation state:

- remediation track is documented in
  `docs/overhaul/plans/v2-post-phase29-remediation-plan.md`
- Phase 30 complete
- Phase 31 complete
- Phase 32 complete
- Phase 35 complete
- remediation track outcome: not ready
- blocker ledger recorded in
  `docs/overhaul/plans/v2-phase35-release-blockers.md`
- follow-on cleanup track documented in
  `docs/overhaul/plans/v2-post-phase35-release-cleanup-plan.md`
- Phase 38 complete
- Phase 39 complete
- cleanup track outcome: ready
- next allowed lane: none inside the current track

Post-Phase-31 staffing rule:

- Phase 35 remains leader-owned integration work
- later remediation work may use a swarm only with disjoint write scopes:
  - playback/diagnostics Rust lane
  - release-readiness/manual-proof lane
  - Flutter boundary-consumption lane
- docs/tests integration stays leader-owned unless explicitly reassigned

Runtime-boundary rule for Phase 18:

- expose retained Flutter repository interfaces first
- keep asset-backed implementations behind those interfaces until Rust-backed
  replacements are ready
- record the runtime replacement map for contract/content/bootstrap ownership
  in a phase doc before Phase 18 is closed

Runtime source-registry rule for Phase 19:

- route Settings-owned provider/auth/import state through the retained runtime
  source registry path
- do not leave provider state owned by legacy `ShellContent` source cards on
  the main runtime path
- keep any legacy-content provider fallback constrained to explicit
  injected-test scaffolding only

Runtime live-TV rule for Phase 20:

- route active Live TV browse/guide/detail state through the retained
  `LiveTvRuntimeRepository` and bootstrap path
- do not leave active group browsing or guide shaping on heuristic
  `ShellContent` slicing once the retained live-TV runtime path exists
- keep any legacy-content live-TV fallback constrained to explicit
  injected-test scaffolding only

Runtime media/search rule for Phase 21:

- route retained Media/Search runtime snapshots through bootstrap-friendly
  repository interfaces before any real provider implementation lands
- keep the phase-21 runtime shapes asset-backed for now so later provider and
  indexing work can replace them without changing the retained runtime shape
- do not move Media/Search runtime shaping into presentation routes or
  view-models while the retained runtime slice is still in progress
- keep any legacy-content Media/Search fallback constrained to explicit
  injected-test scaffolding only

## Lane activation rules

1. Use the smallest team that can finish the current phase safely.
2. Add design lane whenever visual language, Penpot, or Widgetbook is in scope.
3. Add Rust lane only when the approved phase actually requires Rust work.
4. Add verifier lane for every implementation and final-integration phase.

## Handoff rules

1. No phase begins implementation before its planning/design gate is complete.
2. Design artifacts hand off to implementation with explicit board/spec references.
3. Implementation hands off to verification with exact changed-file scope and commands.
4. Verification must produce fresh evidence, never assumed evidence.
5. One vertical must be fully completed before the next vertical starts.

## UI-first stop rule

The team may declare the UI-first baseline complete only when:

- shell is complete and verified
- onboarding/auth/import is complete and verified
- settings is complete and verified
- live TV is complete and verified
- EPG/detail overlays are complete and verified
- movies are complete and verified
- series are complete and verified
- search is complete and verified
- player design gate is complete and verified
- retained player baseline is complete and verified
- UI-first integration evidence exists

## End-product stop rule

The team does not declare the v2 product complete until:

- the UI-first baseline is complete
- Phase 16 player final UI/design completion is complete and verified
- Phase 17 full implementation planning/execution reset is complete
- the later real implementation phases through Phase 29 are executed and
  verified
