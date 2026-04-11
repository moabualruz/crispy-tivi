Task statement

Execute approved CrispyTivi v2 TV rewrite plan in full detail, starting from Phase 1 governance/contracts and continuing through implementation with verification.

Desired outcome

- Phase 1 governance/contracts implemented in repo, not just planned.
- Flutter v2 shell/runtime scaffold exists under app/flutter/lib with MV-only boundaries.
- Rust v2 kernel/workspace scaffold exists under rust/crates with minimal canonical contracts and FFI boundary.
- Quality gates align with branch reality: audit scripts target v2 paths and canonical integration_test entrypoint exists.
- Verification evidence exists for analyze/tests/build as applicable.

Known facts/evidence

- Approved planning artifacts already exist:
  - docs/overhaul/plans/prd-v2-tv-rewrite.md
  - docs/overhaul/plans/test-spec-v2-tv-rewrite.md
  - docs/overhaul/plans/v2-tv-rewrite-execution-plan.md
- Current Flutter code tree is skeletal:
  - app/flutter/lib/.gitkeep
  - app/flutter/test/.gitkeep
  - app/flutter/integration_test/.gitkeep
- rust/Cargo.toml workspace has no members yet.
- Shared Rust IPTV crates already exist under rust/shared/.
- scripts/dart/audit_ddd_solid_dry.sh still targets repo-root lib/.
- scripts/rust/audit_ddd_solid_dry.sh still defaults to rust/crates/crispy-core/src, which does not exist.
- app/flutter/pubspec.yaml already includes flutter_test and integration_test plus flutter_rust_bridge.
- Relevant design doc exists at design/docs/app-overhaul-design-system.md.

Constraints

- Must preserve AGENTS rules: Flutter owns View/ViewModel only; Rust owns controller/business/domain/provider translation.
- No new dependencies unless explicit need; prefer checked-in paths and existing tooling.
- Player implementation remains gated/deferred.
- Need fresh verification before claiming completion.
- Use changed-files-only deslop pass before final completion unless explicitly skipped.

Unknowns/open questions

- Exact minimal Rust crate split for v2 kernel vs FFI.
- Exact first-pass Flutter shell/runtime folder set.
- Smallest set of shell stubs needed to satisfy 'fully navigable shell' for first implementation slice.
- Whether current branch can pass full flutter analyze immediately once scaffold lands without additional generated/config files.

Likely codebase touchpoints

- AGENTS.md
- docs/overhaul/plans/
- docs/overhaul/context/
- app/flutter/pubspec.yaml
- app/flutter/lib/
- app/flutter/test/
- app/flutter/integration_test/
- rust/Cargo.toml
- rust/crates/
- rust/shared/
- scripts/dart/audit_ddd_solid_dry.sh
- scripts/rust/audit_ddd_solid_dry.sh
- design/docs/app-overhaul-design-system.md
