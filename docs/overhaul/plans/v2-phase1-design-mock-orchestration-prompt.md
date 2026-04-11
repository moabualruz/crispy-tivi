# V2 Phase 1-3 Design and Mock Orchestration Prompt

Use this prompt to execute the full design, mock, and mock-integration lane
after Phase 0 reset completion.

## Prompt

You are orchestrating CrispyTivi v2 from the clean restart baseline.

Non-negotiable authority order:

1. `docs/overhaul/plans/v2-conversation-history-full-spec.md`
2. live approved Penpot manifest locked by
   `design/penpot/publish_app_overhaul_design_system.js`
3. `docs/overhaul/plans/v2-reset-baseline-contract.md`
4. `docs/overhaul/plans/v2-tv-rewrite-execution-plan.md`
5. `AGENTS.md`

Mandatory operating rules:

- Read `AGENTS.md` first and obey it strictly.
- These rules apply to the orchestrator and every delegated agent/sub-agent.
- Follow the approved Penpot design as the visual source of truth.
- Flutter owns view and view-model only.
- Rust owns business/domain logic and provider translation only.
- Prefer small, reversible diffs.
- No new dependencies unless explicitly requested.
- Keep tests and analysis green before claiming completion.
- Prefer design-faithful implementation over placeholder/spec-card UI.
- Do not treat scaffolding as adherence.
- Do not infer design from deleted code or old restart artifacts.
- Do not begin real shell implementation until phases 1 to 3 are complete.

Goal:

Finish the design and mock lane end-to-end, then connect mock Rust and mock
Flutter code in a standards-compliant way without crossing the Flutter/Rust
boundary rules.

Required outcomes:

1. Complete and verify the pinned design-system lane from Penpot outward.
2. Complete the Widgetbook/specimen and shell planning lane from the approved
   Penpot boards.
3. Complete shell IA, focus, back/menu, and navigation planning.
4. Define mock domain contracts in Rust for the approved shell flows.
5. Define mock Flutter view/view-model surfaces that consume those Rust mock
   contracts.
6. Integrate mock Rust and mock Flutter code only after the planning gates are
   explicit and satisfied.
7. Keep player work behind the explicit player design gate.

Implementation constraints:

- Penpot is the design source of truth. Code must mirror it.
- Mock Rust code may provide domain/controller outputs and fake data contracts.
- Mock Flutter code may provide screens, view-models, focus/runtime behavior,
  and shell composition only.
- Flutter must not absorb controller/business/provider logic.
- Rust must not absorb pixel layout or directional focus rendering logic.
- Avoid aggregator/barrel drift and broad `mod.rs` surfaces unless explicitly
  justified.
- Preserve narrow file ownership and locality of behavior.

Execution order:

1. verify the pinned Penpot manifest
2. verify Phase 0 completion in the repo docs
3. complete or tighten any remaining Phase 1 artifacts
4. complete or tighten any remaining Phase 2 artifacts
5. complete or tighten any remaining Phase 3 artifacts
6. restate the approved mock Rust/Flutter boundary before writing code
7. implement minimal mock Rust contracts
8. implement minimal mock Flutter views/view-models
9. integrate the mocks
10. run relevant analysis/tests
11. report exactly what changed, what was verified, and what remains blocked

Completion standard:

- No completion claim without explicit evidence.
- If any agent or sub-agent output conflicts with `AGENTS.md`, the authority
  stack, or the pinned Penpot baseline, reject and correct it before proceeding.
