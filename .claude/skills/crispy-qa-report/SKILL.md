---
name: crispy-qa-report
description: Generate comprehensive CrispyTivi QA status report across all 3 pipelines (stub/cached/e2e). Shows overall quality score, cross-pipeline analysis, trend over time. Use when asked to "QA report", "testing summary", "quality status", "how's the app doing", "overall test status". Triggers on: QA report, test summary, quality overview, overall status.
---

# Comprehensive QA Report — CrispyTivi

Cross-pipeline quality analysis — identifies which issues are fundamental (all 3 pipelines) vs data-dependent (e2e only) vs test-infrastructure (stub only).

## Steps

1. **Load ALL available pipeline results:**
   - Read `rust/crates/crispy-ui/tests/output/stub/runs-index.json` (if exists)
   - Read `rust/crates/crispy-ui/tests/output/cached/runs-index.json` (if exists)
   - Read `rust/crates/crispy-ui/tests/output/e2e/runs-index.json` (if exists)
   - For each, read the latest `manifest.json` via `latest_path`
   - Note which pipelines have no runs yet — report them as "not yet run"

2. **Cross-pipeline comparison — for each journey:**
   Compare `status` across stub / cached / e2e:
   | Pattern | Interpretation |
   |---------|---------------|
   | Fails in all 3 | Fundamental UI bug — code fix needed regardless of data |
   | Fails only in e2e | Data-dependent bug — works with stubs, breaks with real IPTV data |
   | Fails only in cached | Cache corruption or stale fixture issue |
   | Fails only in stub | Test data problem — stubs don't match real data structure |
   | Passes in all 3 | Solid — no action needed |

3. **View key screenshots from each pipeline for failing journeys:**
   - Read the first failing PNG from the same journey across different pipelines (Read tool — Claude is multimodal)
   - Do they look different? Does stub show correct layout while e2e shows empty data?
   - This cross-pipeline visual comparison is the primary diagnostic signal

4. **Load analysis files if present:**
   - Read `{pipeline_latest}/analysis/issues.json` for each pipeline
   - Aggregate all issues into a unified view

5. **Calculate quality score:**
   Score = (passing journeys / total journeys) × 100, weighted:
   - E2E pass weight: 50% (most important — real IPTV data)
   - Cached pass weight: 30%
   - Stub pass weight: 20%

6. **Check for trend data (if multiple runs exist):**
   - Read `runs-index.json` for run history (not just latest)
   - For each historic run, note total issues from `manifest.json`
   - Build a simple trend: date → issue count

7. **Generate report:**
   ```markdown
   # QA Report — {date}

   ## Executive Summary
   Overall Quality Score: {score}/100
   Critical blockers: {n}
   Design violations: {n}
   Open issues: {n}

   ## Pipeline Comparison
   | Pipeline | Journeys | Pass | Fail | Blocked | Screenshots | Issues |
   |----------|----------|------|------|---------|-------------|--------|
   | Stub     | 46       | X    | Y    | Z       | NNN         | ZZ     |
   | Cached   | 46       | X    | Y    | Z       | NNN         | ZZ     |
   | E2E      | 46       | X    | Y    | Z       | NNN         | ZZ     |

   ## Cross-Pipeline Analysis

   ### Fundamental Issues (failing in all pipelines)
   These are code bugs — will not fix themselves with better data.
   | Journey | Type | Description | Screenshot |

   ### Data-Dependent Issues (e2e only)
   These pass with stubs but fail with real IPTV sources.
   | Journey | Type | Description | Likely Cause |

   ### Test Infrastructure Issues (stub only)
   Stub test data doesn't match real data structure.
   | Journey | Type | Stub Problem |

   ## Top Priority Fixes
   (ordered by impact × frequency)
   1. {issue} — affects X journeys across Y pipelines

   ## Trend (if multiple runs available)
   | Date | Run | Issues | Fixed | New | Score |
   |------|-----|--------|-------|-----|-------|
   ```

8. **Save report:**
   Write to `F:/work/crispy-tivi/.ai/planning/QA-REPORT.md`

9. **Recommend next steps:**
   - If fundamental issues exist: `/crispy-qa-fix-plan` to generate prioritized fixes
   - If e2e-only failures: investigate real IPTV source data structure vs stub assumptions
   - If stub-only failures: update stub fixtures to match current real data shape
   - If all pass: `/crispy-screenshot-approve` to lock in golden baselines
