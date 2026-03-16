---
name: coverage-sweep
description: Run coverage analysis across all CrispyTivi test projects, identify per-class gaps below target, categorize by testability, and generate a remediation plan. Use when user says "check coverage", "coverage gaps", "what's untested", or "coverage sweep".
---

## Coverage Sweep

### 1. Run Coverage

```bash
rm -rf F:/work/crispy-tivi/coverage-results
dotnet test tests/Crispy.UI.Tests/ --no-restore --filter "Category=Unit" \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/ui
dotnet test tests/Crispy.Domain.Tests/ --no-restore \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/domain
dotnet test tests/Crispy.Application.Tests/ --no-restore \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/application
dotnet test tests/Crispy.Infrastructure.Tests/ --no-restore --filter "Category=Unit" \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/infrastructure
```

`coverage-results/` is gitignored — never commit it.

### 2. Parse Cobertura XML — Best Per-Class

```python
import xml.etree.ElementTree as ET, glob, collections

best = {}  # class_name -> (line_rate, file_path)
for f in glob.glob('coverage-results/**/coverage.cobertura.xml', recursive=True):
    tree = ET.parse(f)
    for c in tree.findall('.//class'):
        name = c.attrib.get('name', '').split('.')[-1]
        rate = float(c.attrib.get('line-rate', 0))
        if name not in best or rate > best[name][0]:
            best[name] = (rate, f)

print(f"{'Class':<45} {'Coverage':>8}  Source")
print("-" * 70)
below = [(n, r, f) for n, (r, f) in sorted(best.items(), key=lambda x: x[1][0]) if r < 0.90]
for name, rate, src in below:
    print(f"{name:<45} {rate*100:>7.0f}%  {src}")
print(f"\nTotal below 90%: {len(below)}")
```

### 3. Categorization

Classify every class below 90% into one of:

| Category | Description |
|---|---|
| **testable-gap** | Real logic exists, tests are missing or incomplete — ACTION REQUIRED |
| **cobertura-artifact** | Sealed `async` state machines (XmltvParser, StalkerClient, etc.) — Cobertura undercounts. Actual coverage is higher. Not a real gap. |
| **arch-ceiling** | Platform bridges, `#if LIBVLC` stubs, DI entry points — untestable by design |
| **axaml-empty** | Code-behind with only `InitializeComponent()` — no testable lines |

Cobertura artifacts to recognize:
- Any sealed class generated from `async` methods (compiler state machines)
- Known examples: `XmltvParser`, `StalkerClient`, `CredentialEncryption`, `MultiviewService`, `SleepTimerService`
- These show ~60% but are well-tested — skip them

### 4. Output Table

Print sorted table (lowest first) with columns: Class | Coverage% | Category | Priority.

Targets:
- Domain entities: ≥ 95%
- ViewModels: ≥ 90%
- Application services: ≥ 90%
- Infrastructure services: ≥ 80%
- Minimum floor: no Domain/UI class below 90% without documented reason

### 5. Generate Remediation Plan

If `testable-gap` classes exist, write plan to `.ai/planning/coverage-gaps-YYYY-MM-DD.md`:

```markdown
# Coverage Gap Remediation — YYYY-MM-DD

## Summary
X classes below target (Y testable-gap, Z artifact/ceiling)

## Testable Gaps (ACTION REQUIRED)
| Class | Current% | Target% | Missing Scenarios |
|---|---|---|---|

## Skipped (Artifacts / Arch Ceiling)
| Class | Reason |
|---|---|
```

### Rules

- Planning docs under `.ai/planning/` are SOURCE OF TRUTH for intended behavior
- When adding tests, verify tests exercise REAL code paths — not mocked-out stubs
- Do NOT inflate coverage with trivial assertions that don't exercise logic
- `dotnet test --no-restore` always — restore is broken
