---
name: crispy-coverage-sweep
description: Run coverage analysis across all CrispyTivi test projects, identify per-class gaps below target, categorize by testability, and generate a remediation plan. Use this skill whenever the user mentions coverage, untested code, test gaps, or asks what needs testing — even if they don't say "coverage sweep" explicitly. Also use after completing any implementation phase to verify coverage targets are met.
---

## Coverage Sweep

### 1. Run Coverage — ALL FOUR Projects

Run ALL four test projects. Missing even one (especially Infrastructure) creates phantom 0% readings. If a project fails to build, document the failure — do not silently skip it.

```bash
rm -rf coverage-results
dotnet test tests/Crispy.Domain.Tests/ --no-restore \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/domain
dotnet test tests/Crispy.Application.Tests/ --no-restore \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/app
dotnet test tests/Crispy.Infrastructure.Tests/ --no-restore \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/infra
dotnet test tests/Crispy.UI.Tests/ --no-restore \
  --collect:"XPlat Code Coverage" --results-directory ./coverage-results/ui
```

`coverage-results/` is gitignored — never commit it.

If any project fails to build or test, report it prominently at the top of the output. Do NOT silently omit it from the analysis.

### 2. Parse Cobertura XML — Best Per-Class Across ALL Assemblies

The same class appears in multiple assembly XMLs (e.g., a Domain entity shows up in Domain.Tests AND Infrastructure.Tests). Take the MAXIMUM coverage for each class name across ALL XML files. This prevents false 0% readings from assemblies that reference but don't exercise a class.

Filter out compiler-generated names containing `<` or `>` and AXAML closure types containing `XamlClosure`.

```python
import xml.etree.ElementTree as ET, glob, os
os.environ['PYTHONIOENCODING'] = 'utf-8'

best = {}  # class_name -> (line_rate, filename)
for f in glob.glob('coverage-results/**/*.cobertura.xml', recursive=True):
    tree = ET.parse(f)
    for c in tree.findall('.//class'):
        name = c.attrib.get('name', '').split('.')[-1]
        fn = c.attrib.get('filename', '')
        if '<' in name or '>' in name or 'XamlClosure' in name:
            continue
        rate = float(c.attrib.get('line-rate', 0)) * 100
        if name not in best or rate > best[name][0]:
            best[name] = (rate, fn)

for k in sorted(best, key=lambda x: best[x][0]):
    p, fn = best[k]
    if p < 90:
        print(f'  {p:5.1f}%  {k}  ({fn})')
```

### 3. Categorization — Use EXACT Labels

Classify every class below 90% into one of these exact categories:

| Category | Label | Description |
|---|---|---|
| Testable gap | `testable-gap` | Real logic exists, tests missing or incomplete — **ACTION REQUIRED** |
| Cobertura artifact | `cobertura-artifact` | Sealed async state machines — Cobertura undercounts. Not a real gap |
| Architecture ceiling | `arch-ceiling` | VLC stubs, EF migrations/snapshots/configs, platform bootstrap, SerilogConfiguration |
| Empty AXAML | `axaml-empty` | Code-behind with only InitializeComponent() or no code at all |

**Known Cobertura artifacts** (show ~60% but are well-tested via async state machines):
`XmltvParser`, `StalkerClient`, `CredentialEncryption`, `MultiviewService`, `SleepTimerService`

**Known arch-ceiling classes:**
`VlcPlayerService`, `TimeshiftService`, `App`, `DependencyInjection`, `SerilogConfiguration`, all EF migrations (`*Schema`, `*ModelSnapshot`, `*Init`), all EF entity configurations

**Known axaml-empty controls** (no code-behind logic):
`BookmarksOverlay`, `EqualizerOverlay`, `LiveEpgStripOverlay`, `MiniPlayerBar`, `PlayerQueueOverlay`, `SettingsCategoryList`, `StreamStatsOverlay`

Everything else below 90% is `testable-gap` unless you can prove otherwise by reading the source.

### 4. Output — Show EVERYTHING, Hide Nothing

Print a sorted table with columns: Coverage% | Class | File | Category

Show ALL classes below 90%. Do NOT filter, exclude, or dismiss any class as "not important". The user explicitly requires full visibility. If you think a class should be excluded, still show it and label it with the correct category — let the user decide.

**Per-file targets (100% target, 5-10% leniency):**
- Domain entities / value objects: ≥ 95%
- Application models / DTOs: ≥ 95%
- Application services: ≥ 90%
- ViewModels: ≥ 90%
- Infrastructure parsers / repos / services: ≥ 90%
- UI Converters / Navigation: ≥ 95%
- Controls/Views with code-behind: test renders + key behaviors

### 5. Generate Remediation Plan

If `testable-gap` classes exist, write plan to `.ai/planning/YYYY-MM-DD-coverage-gaps-N.md`:

```markdown
# Coverage Gap Remediation — YYYY-MM-DD

> **For agentic workers:** Use superpowers:subagent-driven-development to implement.

## Summary
X classes below target (Y testable-gap, Z artifact/ceiling)

## Testable Gaps (ACTION REQUIRED)
| Class | Current% | Target% | File | Missing Scenarios |
|---|---|---|---|---|

## Skipped (Artifacts / Arch Ceiling)
| Class | Category | Reason |
|---|---|---|
```

### Rules

- Planning docs under `.ai/planning/` are SOURCE OF TRUTH for intended behavior
- When adding tests, verify tests exercise REAL code paths — not mocked-out stubs
- Do NOT inflate coverage with trivial assertions that don't exercise logic
- `dotnet test --no-restore` always — restore is broken
- Coverage script is available at `.claude/skills/coverage-sweep/scripts/coverage_parse.py` if needed
