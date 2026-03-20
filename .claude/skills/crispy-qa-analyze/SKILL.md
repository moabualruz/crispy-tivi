---
name: crispy-qa-analyze
description: Deep analysis of CrispyTivi screenshot test results from any pipeline. Reads screenshots + logs, compares against journey specs and design docs, identifies issues with root causes. Use when asked to "analyze test results", "what's wrong", "check screenshots", "diagnose issues", "why is this broken". Triggers on: analyze QA, analyze screenshots, diagnose failures, what's broken.
---

# Deep QA Analysis — CrispyTivi

Analyze the latest test run from any pipeline, combining visual review with structured log analysis.

## Steps

1. **Identify the pipeline to analyze:**
   - If the user specifies a pipeline (`stub`, `cached`, `e2e`), use it
   - Otherwise, find the most recently modified run across all pipelines:
     ```bash
     ls -lt rust/crates/crispy-ui/tests/output/
     ```
   - Read `rust/crates/crispy-ui/tests/output/{pipeline}/runs-index.json` — use `latest_path`

2. **Production Code Path Verification (MANDATORY)**

   **When ANY screen shows empty/missing/stale data, trace the PRODUCTION data flow BEFORE touching the test harness.** Fixing the test harness to mask a production bug is WORSE than leaving the test red.

   a. **Trace the event chain** for the broken screen:
      - `DataEngine` → emits `DataEvent::XxxReady` (e.g., `MoviesReady`, `ChannelsReady`, `SeriesReady`)
      - `data_listener` task in `event_bridge.rs` → stores into `SharedData` + posts to UI via `invoke_from_event_loop`
      - `apply_data_event()` → sets Slint properties, calls `invoke_scroll_xxx(0)`
      - `on_scroll_xxx` callback → reads `SharedData`, calls `bridge.apply_delta()`, populates `VecModel`

   b. **Check ScrollBridge state** (`scroll_integration.rs`):
      - Is `bridge.set_total(data.len())` called with actual data length? If `total==0`, `apply_delta()` always returns `shifted: false`
      - Does `apply_delta()` return `shifted: true`?
      - Is `bridge.reset()` called on forced repopulate (delta==0)?

   c. **Cross-reference screens** to distinguish data vs delivery bugs:
      - Home shows movies but Movies screen empty → data EXISTS, delivery path broken (production bug)
      - Both Home AND Movies empty → data never arrived (sync issue)
      - Only E2E empty, stub works → production sync/populate path broken

   d. **Decision gate:**
      - Production code broken? → **Fix production code FIRST**, then verify test
      - Production code correct + test harness wrong? → Fix test harness
      - **NEVER fix test harness to make screenshots "look right" when production code is broken**

3. **Read manifest:**
   - Read `{latest_path}/manifest.json`
   - Note: total screenshots, pass/fail/new counts, per-journey statuses
   - Identify which journeys have failures, diffs, or are completely new

4. **For EACH journey with failures, diffs, or new screenshots:**

   a. **View every screenshot in order** — use the Read tool on each PNG file (Claude is multimodal)
   b. **Read corresponding log events** from `{latest_path}/logs/test.log` filtered to that journey's timestamps
   c. **Read the journey spec** from `F:/work/crispy-tivi/.ai/planning/USER-JOURNEYS.md`

   At each screenshot step, evaluate:
   - Does the screen shown match what the journey spec says should appear?
   - Does the visual layout match `F:/work/crispy-tivi/.ai/crispy_tivi_design_spec.md`?
   - Are D-pad focus states clearly visible on the expected element?
   - Is data populated, or are lists/cards empty when content is expected?
   - Are there rendering artifacts: red borders, overlapping elements, clipped text, blank areas?
   - Does the navigation state match (correct screen after each action)?

   For each issue, find the corresponding log event that explains it.

5. **Classify each issue:**
   | Type | Meaning |
   |------|---------|
   | `VISUAL_BUG` | Rendering incorrect — wrong layout, colors, clipping, or artifacts |
   | `DATA_BUG` | Wrong or missing data displayed (empty list, wrong title, stale content) |
   | `FOCUS_BUG` | D-pad focus not visible, on wrong element, or not advancing correctly |
   | `NAVIGATION_BUG` | Wrong screen shown after an action (back/forward/select went wrong) |
   | `PERFORMANCE_BUG` | Step took too long per timing entries in logs |
   | `DESIGN_VIOLATION` | Visual output doesn't match design spec or theme tokens |
   | `SPEC_GAP` | Journey step not implemented — screen is blank or shows placeholder |

6. **Correlate issues with production code:**
   For each bug found, use sqry to locate the responsible code:
   - `sqry semantic_search` — find the callback/handler for the triggering action
   - `sqry trace_path` — trace from event emission to UI model population
   - `sqry get_references` — find all call sites for a broken function
   - Search `event_bridge.rs` for the callback, `scroll_integration.rs` for bridge state
   - Check whether `SharedData` is populated AND `VecModel` is updated (both must happen)
   - Do NOT use grep for symbol lookup — sqry has a pre-computed call graph

7. **Output detailed report:**
   For every issue:
   ```
   [ISSUE-{n}] {type} — {journey} / step {step}
   Screenshot: {path}
   Log line:   {line}
   Code:       {file}:{line} — {description of what's wrong}
   Fix:        {specific change needed}
   ```

8. **Save structured issues file:**
   Write to `{latest_path}/analysis/issues.json` so `/crispy-qa-track` and `/crispy-qa-fix-plan` can consume it.

## Quick Mode

If the user asks for a quick check (e.g., "just tell me what's broken"), limit to:
- Journeys with `status: "fail"` in the manifest only
- First failing screenshot per journey
- Log context: 10 lines around the failure timestamp
