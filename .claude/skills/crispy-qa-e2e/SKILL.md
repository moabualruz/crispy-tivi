---
name: crispy-qa-e2e
description: Run full E2E screenshot tests with real IPTV sources, then analyze screenshots and logs against CrispyTivi journey specs and design docs. Use when asked to "run e2e tests", "test with real data", "full QA", "e2e validation", "test real sources", "end-to-end test". Triggers on: e2e tests, real source test, full QA pipeline.
---

# E2E Visual QA Pipeline — CrispyTivi

Run Pipeline 3 (E2E) — fresh DB, real source sync, full user journey simulation.

## Prerequisites
- `rust/crates/crispy-ui/tests/fixtures/test-settings.local.json` must exist with real IPTV source credentials
- Network access to IPTV servers required

## Steps

1. **Verify prerequisites:**
   ```bash
   ls rust/crates/crispy-ui/tests/fixtures/test-settings.local.json
   ```
   If missing, ask the user for source credentials before proceeding.

2. **Run E2E pipeline:**
   ```bash
   cd rust && CRISPY_PIPELINE=e2e cargo test -p crispy-ui --test screenshots -- --nocapture
   ```
   This takes 5–15 minutes (real sync + all 46 journeys).

3. **Find latest results:**
   - Read `rust/crates/crispy-ui/tests/output/e2e/runs-index.json`
   - Use `latest_path` to locate the run directory

4. **Analyze screenshots:**
   For each journey directory in `{latest_path}/test/`:
   - View every PNG screenshot using the Read tool (Claude is multimodal — view images directly)
   - Read the corresponding entries in `{latest_path}/manifest.json` for journey context
   - Compare against:
     - `F:/work/crispy-tivi/.ai/planning/USER-JOURNEYS.md` — journey step expectations
     - `F:/work/crispy-tivi/.ai/crispy_tivi_design_spec.md` — visual design rules
     - `F:/work/crispy-tivi/.impeccable.md` — design principles

5. **Analyze logs:**
   - Read `{latest_path}/logs/test.log` — check for errors, warnings, unexpected events
   - Read `{latest_path}/logs/sync.log` — verify sources synced, check channel/VOD counts
   - Read `{latest_path}/logs/network.log` — check for failed HTTP requests and timeouts
   - Correlate log events with screenshot issues (e.g., `image_load_failed` → blank poster in screenshot)

6. **Cross-reference visual + log issues:**
   For each visual problem found:
   - Find the log event that explains WHY (network error? missing data? wrong property binding?)
   - Identify root cause: code bug vs data issue vs design gap vs missing wiring

7. **Produce QA report:**
   ```markdown
   ## E2E QA Report — {date}

   ### Pipeline Results
   - Sources synced: X (Y channels, Z movies, W series)
   - Sync errors: [list]
   - Journeys: X pass / Y fail / Z blocked

   ### Critical Issues (with screenshot + log evidence)
   | # | Journey | Screenshot | Visual Issue | Log Evidence | Root Cause | Fix |
   |---|---------|-----------|-------------|-------------|------------|-----|

   ### Design Violations
   | # | Screenshot | Rule Violated | Expected | Actual |
   |---|-----------|--------------|---------|--------|

   ### Performance Concerns
   | # | Step | Duration | Threshold | Log Event |
   |---|------|---------|---------|-----------|

   ### Network Issues
   | # | URL | Status | Impact |
   |---|-----|--------|--------|
   ```

8. **Write issues file:**
   Save structured issues to `{latest_path}/analysis/issues.json`:
   ```json
   {
     "run_id": "...",
     "pipeline": "e2e",
     "generated_at": "...",
     "issues": [
       {
         "id": "issue-001",
         "severity": "critical|high|medium|low",
         "type": "VISUAL_BUG|DATA_BUG|FOCUS_BUG|NAVIGATION_BUG|PERFORMANCE_BUG|DESIGN_VIOLATION|SPEC_GAP",
         "journey": "...",
         "step": "...",
         "screenshot": "path/to/screenshot.png",
         "log_line": "...",
         "description": "...",
         "root_cause": "...",
         "suggested_fix": "..."
       }
     ]
   }
   ```

9. **Suggest next steps:**
   - If critical issues found: run `/crispy-qa-fix-plan` to generate an actionable fix plan
   - If design violations found: run `/crispy-screenshot-design-audit` for a full design audit
   - If all journeys pass: run `/crispy-screenshot-approve` to accept as golden baseline

### Post-Run Verification (MANDATORY)
- Verify sync produced non-zero counts: check logs for `channels=X vod=Y` where X,Y > 0
- If sync count is zero, the E2E run is invalid — investigate sync credentials/network before analyzing screenshots
- After E2E completes, invoke `/crispy-qa-analyze` which includes mandatory production code path verification
- Network timeout: E2E sync timeout is 120s. If exceeded, check credentials in `test-settings.local.json`
