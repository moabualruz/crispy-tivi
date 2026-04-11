Task statement

Execute Phase 4 shell implementation kickoff for CrispyTivi v2 from the approved design/planning baseline.

Desired outcome

- Flutter shell core/framework, shell route surfaces, and minimal Rust shell-support contracts start in parallel without file conflicts.
- All lanes follow AGENTS.md and the assigned skills.
- Fresh analyze/test/integration evidence is produced.

Known facts/evidence

- Authoritative product spec: docs/overhaul/plans/v2-conversation-history-full-spec.md
- Execution stack and team/skill routing docs already exist under docs/overhaul/plans/
- Penpot design baseline exists and is treated as accepted for execution kickoff.
- Zero-conflict lane ownership defined in docs/overhaul/plans/v2-phase4-shell-kickoff.md

Constraints

- Flutter = View/ViewModel only
- Rust = controller/business/domain orchestration only
- No provider-native leakage into Flutter
- No overlapping write scopes between lanes
- Each lane must use its assigned skills and follow AGENTS.md exactly

Unknowns/open questions

- Exact first shell files each implementation lane will create
- Whether Rust lane needs any changes in the first kickoff slice or can remain support-only

Likely codebase touchpoints

- app/flutter/lib/app/
- app/flutter/lib/core/
- app/flutter/lib/features/
- app/flutter/test/
- app/flutter/integration_test/
- rust/crates/
- docs/overhaul/plans/v2-phase4-shell-kickoff.md
