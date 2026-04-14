# Phase 26: Demo/Test Gating and First-Run Truth

Status: complete
Date: 2026-04-13

## Purpose

Phase 26 removes the ambiguity between:

- real default application behavior
- explicit demo mode
- test-only fixture behavior

The default app boot must be truthful for a fresh install.

## Required outcomes

- seeded/mock/demo data is never the default boot path
- demo mode remains available only through explicit gating
- tests remain able to inject deterministic fixtures without contaminating the
  real runtime path
- first-run behavior is verified with zero configured providers

## Closure rules

Phase 26 is complete only when:

- default startup contains no seeded providers/content/personalization
- first-run onboarding starts from a true zero-provider state
- demo/test mode is explicit and documented
- the resulting startup rules are covered by tests and governing docs

## Completed work

- runtime mode selection is now first-class through `AppRuntimeProfile`
  instead of being split across app bootstrap defaults
- default app boot resolves through the explicit `real` profile:
  - `RuntimeShellBootstrapRepository`
  - unseeded `PersistedPersonalizationRuntimeRepository`
- explicit demo mode resolves through the explicit `demo` profile:
  - `AssetShellBootstrapRepository`
  - seeded `PersistedPersonalizationRuntimeRepository`
- test fixtures remain available through explicit repository injection and no
  longer depend on implicit seeded startup behavior

## Verification evidence

- `flutter test test/app/app_bootstrap_test.dart`
- `flutter test test/features/shell/runtime_shell_bootstrap_repository_test.dart`

## Result

- real mode, demo mode, and injected fixture mode are now distinct and
  test-covered startup policies
- the next allowed lane is `Phase 27`
