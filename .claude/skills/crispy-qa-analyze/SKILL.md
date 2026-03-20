---
name: crispy-qa-analyze
description: Deep analysis of CrispyTivi Flutter screenshot/golden test results from any pipeline. Reads golden failures + logs, compares against journey specs and design docs, identifies issues with root causes. Use when asked to "analyze test results", "what's wrong", "check screenshots", "diagnose issues", "why is this broken". Triggers on: analyze QA, analyze screenshots, diagnose failures, what's broken.
---

# Deep QA Analysis — CrispyTivi Flutter

Analyze the latest test run, combining visual review (Flutter golden failures) with structured log analysis.

## Steps

1. **Identify the pipeline to analyze:**
   - If the user specifies a pipeline (`stub`, `cached`, `e2e`), use it
   - Otherwise, find the most recently modified run across all pipelines:
     ```bash
     ls -lt test/output/
     ```
   - Read `test/output/{pipeline}/runs-index.json` — use `latest_path`

2. **Production Code Path Verification (MANDATORY)**

   **When ANY screen shows empty/missing/stale data, trace the PRODUCTION data flow BEFORE touching the test harness.** Fixing the test harness to mask a production bug is WORSE than leaving the test red.

   a. **Trace the event chain** for the broken screen:
      - `DataEngine` (in `rust/crates/crispy-core/`) → emits data events
      - Flutter `DataProvider` → receives events via platform channel or WebSocket
      - `ChangeNotifier` / Riverpod `Notifier` → stores state, notifies UI
      - Widget tree → rebuilds from state, renders list/grid

   b. **Check state management:**
      - Is the provider receiving non-empty data? Add debug print in provider.
      - Does `notifyListeners()` / `state = newState` fire after data arrives?
      - Is the widget's `Consumer` / `watch` actually subscribing to the right provider?

   c. **Cross-reference screens** to distinguish data vs delivery bugs:
      - Home shows movies but Movies screen empty → data EXISTS, delivery path broken (production bug)
      - Both Home AND Movies empty → data never arrived (sync/channel issue)
      - Only E2E empty, stub works → production sync/populate path broken

   d. **Decision gate:**
      - Production code broken? → **Fix production code FIRST**, then verify test
      - Production code correct + test harness wrong? → Fix test harness
      - **NEVER fix test harness to make golden images "look right" when production code is broken**

3. **Read manifest:**
   - Read `{latest_path}/manifest.json`
   - Note: total screenshots, pass/fail/new counts, per-journey statuses
   - Identify which journeys have failures, diffs, or are completely new

4. **For EACH journey with failures, diffs, or new screenshots:**

   a. **View every screenshot in order** — use the Read tool on each PNG file (Claude is multimodal)
   b. **Read corresponding log events** from `{latest_path}/logs/test.log` filtered to that journey's timestamps
   c. **Read the journey spec** from `F:/work/crispi-tv-flutter/.ai/planning/USER-JOURNEYS.md`

   At each screenshot step, evaluate:
   - Does the screen shown match what the journey spec says should appear?
   - Does the visual layout match `F:/work/crispi-tv-flutter/.ai/crispy_tivi_design_spec.md`?
   - Are D-pad / focus states clearly visible on the expected element?
   - Is data populated, or are lists/cards empty when content is expected?
   - Are there rendering artifacts: overlapping elements, clipped text, blank areas?
   - Does the navigation state match (correct screen after each action)?

   For each issue, find the corresponding log event that explains it.

5. **Classify each issue:**
   | Type | Meaning |
   |------|---------|
   | `VISUAL_BUG` | Rendering incorrect — wrong layout, colors, clipping, or artifacts |
   | `DATA_BUG` | Wrong or missing data displayed (empty list, wrong title, stale content) |
   | `FOCUS_BUG` | Focus not visible, on wrong element, or not advancing correctly |
   | `NAVIGATION_BUG` | Wrong screen shown after an action (back/forward/select went wrong) |
   | `PERFORMANCE_BUG` | Step took too long per timing entries in logs |
   | `DESIGN_VIOLATION` | Visual output doesn't match design spec or theme tokens |
   | `SPEC_GAP` | Journey step not implemented — screen is blank or shows placeholder |

6. **Correlate issues with production code:**
   For each bug found, use sqry to locate the responsible code:
   - `sqry semantic_search` — find the widget/provider for the triggering action
   - `sqry trace_path` — trace from event emission to widget render
   - `sqry get_references` — find all call sites for a broken function
   - Search `lib/providers/` for state management, `lib/screens/` for widgets
   - Check whether provider state is populated AND widget is subscribed (both must happen)
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
