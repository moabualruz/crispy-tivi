---
name: rice-screenshot-run
description: Run screenshot journey tests and report results. Use when asked to "run screenshot tests", "capture screenshots", "test journeys visually", or "visual regression test".
---

# Run Screenshot Journey Tests

## Steps

1. Run the screenshot test suite:
   ```bash
   cargo test -p crispy-ui --test screenshots -- --nocapture
   ```

2. Read the runs index to find latest run:
   ```
   Read: rust/crates/crispy-ui/tests/runs/runs-index.json
   ```

3. Read the manifest from the latest run:
   ```
   Read: {latest_path}/manifest.json
   ```

4. Print summary:
   ```
   Screenshot Test Results
   Run: {run_id} | Commit: {git_commit}
   Total: {total} | Passed: {passed} | Failed: {failed} | New: {new}
   Journeys: {journeys_passed} pass | {journeys_failed} fail | {journeys_blocked} blocked
   ```

5. If failures exist:
   - List each failed screenshot with its journey_step and diff_pct
   - Suggest: "Run `/rice-screenshot-review` to analyze failures against design specs"

6. If new screenshots exist:
   - List each new screenshot
   - Suggest: "Run `/rice-screenshot-approve` to review and approve new baselines"

## Environment Variables

- `CRISPY_JOURNEY_FILTER` — run specific journeys (e.g., `j05*`)
- `CRISPY_TEST_RESOLUTION` — render resolution (default `1280x720`)
- `CRISPY_UPDATE_SNAPSHOTS=1` — regenerate all golden baselines
