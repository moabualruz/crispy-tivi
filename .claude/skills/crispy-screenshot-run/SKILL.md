---
name: crispy-screenshot-run
description: Run CrispyTivi Flutter golden/screenshot tests and report results. Executes the visual test suite against stub/cached/e2e pipelines, reads the manifest, and prints pass/fail summary. Use when asked to "run screenshot tests", "capture screenshots", "test journeys visually", "visual regression test", "run visual tests", "update goldens". Triggers on: run screenshot tests, run visual tests, capture screenshots, visual regression, update goldens.
---

# Run Screenshot / Golden Tests — CrispyTivi Flutter

## Steps

1. Run the Flutter golden test suite:
   ```bash
   # Run golden tests (compare against existing baselines):
   flutter test test/golden/

   # Update all golden baselines (regenerate):
   flutter test test/golden/ --update-goldens

   # Run a specific pipeline:
   CRISPY_PIPELINE=stub flutter test test/golden/
   CRISPY_PIPELINE=cached flutter test test/golden/
   CRISPY_PIPELINE=e2e flutter test test/golden/
   ```

2. Read the runs index to find latest run:
   ```
   Read: test/output/{pipeline}/runs-index.json
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

6. If new screenshots exist (no baseline yet):
   - List each new screenshot
   - Suggest: "Run `/crispy-screenshot-approve` to review and approve new baselines"

## Environment Variables

- `CRISPY_PIPELINE=stub|cached|e2e` — select pipeline (default: `stub`)
- `CRISPY_JOURNEY_FILTER` — run specific journeys (e.g., `j05*`)
- `CRISPY_TEST_RESOLUTION` — render resolution (default `1280x720`)

## Flutter Golden Test Notes

- Golden files live in `test/golden/goldens/` — committed to git
- `flutter test --update-goldens` regenerates all baseline images
- On CI, run WITHOUT `--update-goldens` so failures are caught
- Font rendering differences between platforms can cause false positives — use `matchesGoldenFile` with tolerance or a shared test font

### Error Type Disambiguation
Distinguish between:
1. **Compilation failure** — `flutter test` won't build → fix Dart errors first (`flutter analyze`)
2. **Test panic during sync** — sync crashes in integration test → check credentials, network, source availability
3. **Golden mismatch** — pixel diff exceeds threshold → invoke `/crispy-screenshot-review` with production code path verification
4. **Missing golden** — no baseline exists yet → run with `--update-goldens` to create baseline, then `/crispy-screenshot-approve`
5. After run completes, check `test.log` for any `status: fail` entries before declaring success
