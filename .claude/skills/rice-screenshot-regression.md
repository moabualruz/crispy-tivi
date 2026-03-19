---
name: rice-screenshot-regression
description: Analyze visual regressions across multiple test runs. Use when asked to "regression analysis", "what broke visually", "compare runs", "visual diff between commits".
---

# Cross-Run Regression Analysis

## Steps

1. **Load run history:**
   - Read `rust/crates/crispy-ui/tests/runs/runs-index.json`
   - Get the latest 2 runs (or N runs if specified)

2. **Compare manifests:**
   - Read `manifest.json` from each run
   - For each screenshot ID, compare status across runs:
     - **New regression:** was `pass` in old run, now `fail`
     - **Fixed:** was `fail` in old run, now `pass`
     - **Persistent failure:** `fail` in both runs
     - **New screenshot:** exists in new run but not old
     - **Removed screenshot:** exists in old run but not new

3. **Cross-reference git:**
   - Get commits between the two runs: `git log {old_commit}..{new_commit} --oneline`
   - For each new regression, identify which files changed that could affect that journey's screen

4. **Output regression report:**
   ```
   ## Regression Report: {old_run} → {new_run}

   ### New Regressions (were passing, now failing)
   | Screenshot | Journey | Diff % | Likely Commit |
   |------------|---------|--------|---------------|

   ### Fixed (were failing, now passing)
   | Screenshot | Journey |

   ### Persistent Failures
   | Screenshot | Journey | Runs Failing |
   ```
