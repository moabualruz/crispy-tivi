# V2 Team Assembly Plan

Status: Completed
Date: 2026-04-11

## Purpose

Define how the team should be assembled to execute the **entire v2 product**
from planning through final player implementation and completion, not only the
opening phases.

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

#### Phase 11: series completion

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

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

#### Phase 14: player implementation

- leader
- design lane
- Flutter lane
- Rust lane
- verifier lane

### Finish-product phase

#### Phase 15: final integration / completion hardening

- leader
- Flutter lane
- Rust lane
- verifier lane
- design lane only if final visual corrections are still required

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

## End-product stop rule

The team does not declare the v2 product complete until:

- shell is complete and verified
- onboarding/auth/import is complete and verified
- settings is complete and verified
- live TV is complete and verified
- EPG/detail overlays are complete and verified
- movies are complete and verified
- series are complete and verified
- search is complete and verified
- player design gate is complete and verified
- player is complete and verified
- final integration evidence exists
