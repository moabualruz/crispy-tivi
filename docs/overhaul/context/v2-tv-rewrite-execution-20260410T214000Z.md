Task statement

Execute approved CrispyTivi v2 TV rewrite plan in full detail starting from Phase 1 governance/contracts and continue implementation without shortcuts until verified complete.

Desired outcome

- v2 rewrite implementation scaffold exists in Flutter and Rust.
- Quality gates align with v2 branch layout.
- Fully navigable shell/stub foundation exists on shared windowed/input/navigation primitives.
- Rust canonical kernel/FFI boundary exists for future vertical delivery.
- Verification evidence is fresh and recorded.

Known facts/evidence

- Planning artifacts already approved:
  - `docs/overhaul/plans/prd-v2-tv-rewrite.md`
  - `docs/overhaul/plans/test-spec-v2-tv-rewrite.md`
  - `docs/overhaul/plans/v2-tv-rewrite-execution-plan.md`
- Current app code is skeletal:
  - `app/flutter/lib/.gitkeep`
  - `app/flutter/test/.gitkeep`
  - `app/flutter/integration_test/.gitkeep`
- Rust workspace exists in `rust/Cargo.toml`; shared crates exist under `rust/shared/`.
- Existing audit scripts are misaligned with v2 paths:
  - `scripts/dart/audit_ddd_solid_dry.sh` targets repo-root `lib`
  - `scripts/rust/audit_ddd_solid_dry.sh` defaults to missing `rust/crates/crispy-core/src`
- `docs/shared/agent-tiers.md` is absent in repo.

Constraints

- Follow AGENTS.md: Flutter MV-only, Rust owns orchestration/domain/provider translation, player last, shared design tokens under `app/flutter/lib/core/theme/`, shared widgets under `app/flutter/lib/core/widgets/`.
- No new dependencies unless already present in checked-in config or explicitly needed by existing stack.
- Prefer small, reversible diffs, but user requested no shortcuts; execute full approved plan incrementally with verification.
- Must verify before claiming completion.

Unknowns/open questions

- Exact minimal shell scope achievable in one Ralph iteration before deeper verticals.
- Exact FFI crate naming and how much real Rust contract surface to stub now vs later.
- Whether existing Flutter pubspec already includes libraries needed for Widgetbook/integration harness for v2 shell tests.

Likely codebase touchpoints

- `app/flutter/pubspec.yaml`
- `app/flutter/lib/`
- `app/flutter/test/`
- `app/flutter/integration_test/`
- `rust/Cargo.toml`
- `rust/crates/`
- `scripts/dart/audit_ddd_solid_dry.sh`
- `scripts/rust/audit_ddd_solid_dry.sh`
- `docs/overhaul/plans/`
- `AGENTS.md`
