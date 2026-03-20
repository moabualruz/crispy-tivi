---
name: crispy-test-audit
description: Audit all tests against phase planning docs in .ai/planning/phases/ to verify code and tests match the planned behavior. Use whenever completing a phase, reviewing test quality, or when user says 'audit', 'check alignment', 'verify tests'. The planning docs are always the source of truth — production code that deviates from the plan is wrong.
---

## Test Audit

### 1. Read ALL Plan Files First

**Before auditing any code**, read every file in the phase directory:

```
.ai/planning/phases/XX-name/
  ├── SPEC.md          # Feature list and acceptance criteria
  ├── BEHAVIORS.md     # Behavioral specs and state machine rules
  ├── DECISIONS.md     # Architecture and design decisions
  └── *.md             # Any other planning files
```

Read ALL of them. Do not start code inspection until you have a complete picture of what was planned. Partial reading leads to false `code-deviation` flags or missed gaps.

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

### 3. Trivial vs Real Tests — Examples

**Trivial (flag as `test-trivial`):**
```csharp
// Mock returns default, assertion is vacuous — nothing is actually tested
playerService.State.Returns(PlayerState.Idle);
var vm = new PlayerViewModel(playerService, ...);
vm.IsPlaying.Should().BeFalse();  // IsPlaying is false by default — no behavior exercised
```

**Real (pass):**
```csharp
// State is pushed, derived property is asserted to change
var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
stateSubject.OnNext(new PlayerState { IsPlaying = true });
vm.IsPlaying.Should().BeTrue();  // Reactive subscription actually fired
```

### 4. Flag Categories

| Flag | Meaning | Action |
|---|---|---|
| `test-wrong` | Test asserts the wrong thing — passes even when feature is broken | Rewrite assertion to match plan spec |
| `test-trivial` | Test passes without exercising real code (mocks return default, assertion is vacuous) | Rewrite to verify behavior |
| `test-missing` | No test exists for a planned feature | Write test |
| `code-deviation` | Production code does something different from what the plan specifies | Fix production code |
| `plan-gap` | Plan is underspecified — behavior unclear | Ask user to clarify plan, then update plan first |

### 5. Never Short-Circuit

If a test is hard to set up:
- Fix the setup (DI, mocks, DataContext, InitializeComponent)
- Do NOT weaken assertions to make the test easier
- Do NOT skip edge cases because they're inconvenient

If a feature can't be tested as-is, apply `make-testable` skill first.

### 6. Output Report

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

### 7. Rules

- Read the actual test bodies — do not infer from method names
- A test named `PlayAsync_SetsIsPlayingTrue` that never calls `PlayAsync()` is `test-wrong`
- Planning docs under `.ai/planning/` override any assumptions about "how it should work"
- If code deviates from the plan, the code is wrong — change the code, not the plan
- Commit the audit report to the `.ai` submodule, not to the main repo
