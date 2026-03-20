---
name: crispy-screenshot-run
description: Run CrispyTivi screenshot journey tests and report results. Executes the visual test suite against stub/cached/e2e pipelines, reads the manifest, and prints pass/fail summary. Use when asked to "run screenshot tests", "capture screenshots", "test journeys visually", "visual regression test", "run visual tests". Triggers on: run screenshot tests, run visual tests, capture screenshots, visual regression.
---

# Run Screenshot Journey Tests — CrispyTivi

## Steps

1. Run the screenshot test suite:
   ```bash
   cargo test -p crispy-ui --test screenshots -- --nocapture
   ```

2. Read the runs index to find latest run:
   ```
   Read: rust/crates/crispy-ui/tests/output/{pipeline}/runs-index.json
   ```
   Default pipeline is `stub` unless user specifies `cached` or `e2e`.

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
   - Suggest: "Run `/crispy-screenshot-review` to analyze failures against design specs"

6. If new screenshots exist:
   - List each new screenshot
   - Suggest: "Run `/crispy-screenshot-approve` to review and approve new baselines"

## Environment Variables

- `CRISPY_PIPELINE=stub|cached|e2e` — select pipeline (default: `stub`)
- `CRISPY_JOURNEY_FILTER` — run specific journeys (e.g., `j05*`)
- `CRISPY_TEST_RESOLUTION` — render resolution (default `1280x720`)
- `CRISPY_UPDATE_SNAPSHOTS=1` — regenerate all golden baselines
