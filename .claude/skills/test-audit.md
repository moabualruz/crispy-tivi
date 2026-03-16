---
name: test-audit
description: Audit all tests against phase planning docs in .ai/planning/phases/ to verify alignment. Use when user says "audit tests", "check alignment", "verify tests match plan", or after completing a phase.
---

## Test Audit

### 1. Read Phase Plans

Phase plans live in `.ai/planning/phases/XX-name/`. For each phase:
- Read the feature list
- Read acceptance criteria
- Read any behavioral specs

Planning docs are **SOURCE OF TRUTH**. If code deviates from plan, the code is wrong — not the plan.

### 2. Audit Each Planned Feature

For every planned feature verify all of the following:

| Check | Pass Condition |
|---|---|
| Production code exists | File exists, class/method matches plan's ubiquitous language |
| Tests exist | At least one test file targeting the class |
| Tests exercise REAL code | No `Should_Pass_When_Nothing_Happens` pattern — assertions verify actual state changes |
| Assertions are meaningful | `.Should().BeTrue()` on a value that's always true = trivial |
| Edge cases covered | Error paths, null inputs, boundary values tested |

### 3. Flag Categories

| Flag | Meaning | Action |
|---|---|---|
| `test-wrong` | Test asserts the wrong thing — passes even when feature is broken | Rewrite assertion to match plan spec |
| `test-trivial` | Test passes without exercising real code (mocks return default, assertion is vacuous) | Rewrite to verify behavior |
| `test-missing` | No test exists for a planned feature | Write test |
| `code-deviation` | Production code does something different from what the plan specifies | Fix production code |
| `plan-gap` | Plan is underspecified — behavior unclear | Ask user to clarify plan, then update plan first |

### 4. Never Short-Circuit

If a test is hard to set up:
- Fix the setup (DI, mocks, DataContext, InitializeComponent)
- Do NOT weaken assertions to make the test easier
- Do NOT skip edge cases because they're inconvenient

If a feature can't be tested as-is, apply `make-testable` skill first.

### 5. Output Report

Write audit report to `.ai/planning/test-audit-YYYY-MM-DD.md`:

```markdown
# Test Audit — YYYY-MM-DD

## Phase: XX-name

### Passing ✓
- FeatureName — tests exist, cover real code, assertions meaningful

### Flags
| Feature | Flag | File | Description |
|---|---|---|---|
| FeatureName | test-trivial | ViewModels/FooViewModelTests.cs:42 | Should().BeTrue() on constant |

### Missing Tests
- FeatureName — no tests found

### Code Deviations
- FeatureName — plan says X, code does Y (file:line)

## Summary
X features audited, Y passing, Z flagged
```

### 6. Rules

- Read the actual test bodies — do not infer from method names
- A test named `PlayAsync_SetsIsPlayingTrue` that never calls `PlayAsync()` is `test-wrong`
- Planning docs under `.ai/planning/` override any assumptions about "how it should work"
- Commit the audit report to the `.ai` submodule, not to the main repo
