Task statement

Execute approved CrispyTivi v2 TV rewrite plan in detail with no skipped foundational work. Start from Phase 1 governance/contracts, then scaffold shell/runtime foundations and Rust kernel/FFI so repo moves from skeletal branch toward executable v2 app structure.

Desired outcome

- Phase 1 governance/contracts implemented, not just documented.
- Audit scripts aligned with v2 paths.
- Canonical integration test entrypoint exists.
- Flutter v2 shell/runtime scaffold exists with navigable stub screens, shared input/windowing primitives, and tests.
- Rust v2 domain + FFI scaffolds exist with kernel contracts and tests.
- Verification evidence collected.

Known facts/evidence

- Planning artifacts already approved: `docs/overhaul/plans/prd-v2-tv-rewrite.md`, `docs/overhaul/plans/test-spec-v2-tv-rewrite.md`, `docs/overhaul/plans/v2-tv-rewrite-execution-plan.md`.
- `app/flutter/lib/`, `app/flutter/test/`, and `app/flutter/integration_test/` are skeletal (`.gitkeep` only).
- `app/flutter/pubspec.yaml` already includes Flutter, Riverpod, go_router, flutter_rust_bridge, widgetbook, and integration_test dependencies.
- `rust/Cargo.toml` workspace exists but has no members.
- `app/flutter/flutter_rust_bridge.yaml` expects `../../rust/crates/crispy-ffi/` with Rust input `crate::api`.
- Existing quality-gate scripts are stale for this branch shape.
- `docs/shared/agent-tiers.md` is absent, so delegation tier reference cannot be loaded verbatim.

Constraints

- Follow AGENTS.md and active Ralph/ralplan gates.
- Keep Flutter MV-only; no business/provider logic in Dart.
- Rust owns canonical contracts and FFI-facing orchestration seams.
- Prefer deletion/reuse over new dependency additions.
- Must verify with fresh evidence before claiming completion.

Unknowns/open questions

- Exact first-pass shell stub shape that best balances navigability with minimal placeholder logic.
- Whether FRB codegen is already available locally or should remain a later wiring step.
- Whether full player/vertical implementation fits current Ralph iteration scope after foundations land.

Likely codebase touchpoints

- `app/flutter/lib/`
- `app/flutter/test/`
- `app/flutter/integration_test/`
- `app/flutter/pubspec.yaml`
- `rust/Cargo.toml`
- `rust/crates/`
- `scripts/dart/audit_ddd_solid_dry.sh`
- `scripts/rust/audit_ddd_solid_dry.sh`
- `docs/overhaul/plans/`
