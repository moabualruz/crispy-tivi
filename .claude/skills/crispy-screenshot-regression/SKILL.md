---
name: crispy-screenshot-regression
description: Analyze visual regressions in CrispyTivi across multiple test runs. Compares screenshots between runs, classifies changes, and correlates regressions with git commits. Use when asked to "regression analysis", "what broke visually", "compare runs", "visual diff between commits", "what changed visually". Triggers on: regression analysis, visual diff, compare runs, what broke.
---

# Cross-Run Regression Analysis — CrispyTivi

## Steps

1. **Load run history:**
   - Read `rust/crates/crispy-ui/tests/output/{pipeline}/runs-index.json`
   - Get the latest 2 runs (or N runs if specified by user)

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
   - For each new regression, identify which Rust/Slint files changed that could affect that journey's screen

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

5. **Recommend next steps:**
   - For regressions: "Run `/crispy-qa-analyze` to deep-dive failing journeys"
   - For improvements: "Run `/crispy-screenshot-approve` to lock in improvements as new baselines"

### Regression Source Analysis
- When regression appears only in E2E pipeline, check if production data flow changed (event_bridge.rs, scroll_integration.rs)
- Correlate regression timestamp with `git log --since` to identify the breaking commit
- If regression involves empty screens, check ScrollBridge.set_total() and apply_delta() before blaming UI changes
