---
name: crispy-qa-analyze
description: Deep analysis of screenshot test results from any pipeline. Reads screenshots + logs, compares against specs, identifies issues with root causes. Use when asked to "analyze test results", "what's wrong", "check screenshots", "diagnose issues", "why is this broken".
---

# Deep QA Analysis

Analyze the latest test run from any pipeline, combining visual review with structured log analysis.

## Steps

1. **Identify the pipeline to analyze:**
   - If the user specifies a pipeline (`stub`, `cached`, `e2e`), use it
   - Otherwise, find the most recently modified run across all pipelines:
     ```bash
     ls -lt rust/crates/crispy-ui/tests/output/
     ```
   - Read `tests/output/{pipeline}/runs-index.json` — use `latest_path`

2. **Read manifest:**
   - Read `{latest_path}/manifest.json`
   - Note: total screenshots, pass/fail/new counts, per-journey statuses
   - Identify which journeys have failures, diffs, or are completely new

3. **For EACH journey with failures, diffs, or new screenshots:**

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

4. **Classify each issue:**
   | Type | Meaning |
   |------|---------|
   | `VISUAL_BUG` | Rendering incorrect — wrong layout, colors, clipping, or artifacts |
   | `DATA_BUG` | Wrong or missing data displayed (empty list, wrong title, stale content) |
   | `FOCUS_BUG` | D-pad focus not visible, on wrong element, or not advancing correctly |
   | `NAVIGATION_BUG` | Wrong screen shown after an action (back/forward/select went wrong) |
   | `PERFORMANCE_BUG` | Step took too long per timing entries in logs |
   | `DESIGN_VIOLATION` | Visual output doesn't match design spec or theme tokens |
   | `SPEC_GAP` | Journey step not implemented — screen is blank or shows placeholder |

5. **Correlate issues with code:**
   For each bug found, use CodeSearch to locate the responsible code:
   - Search `event_bridge.rs` for the callback that should handle the triggering action
   - Search the relevant `.slint` file for the component that renders incorrectly
   - Check whether the Rust side sets the expected property on the Slint component
   - Use `mcp__codesearch__symbol_search` or `mcp__codesearch__text_search` — do NOT grep manually

6. **Output detailed report:**
   For every issue:
   ```
   [ISSUE-{n}] {type} — {journey} / step {step}
   Screenshot: {path}
   Log line:   {line}
   Code:       {file}:{line} — {description of what's wrong}
   Fix:        {specific change needed}
   ```

7. **Save structured issues file:**
   Write to `{latest_path}/analysis/issues.json` so `/rice-qa-track` and `/rice-qa-fix-plan` can consume it.

## Quick Mode

If the user asks for a quick check (e.g., "just tell me what's broken"), limit to:
- Journeys with `status: "fail"` in the manifest only
- First failing screenshot per journey
- Log context: 10 lines around the failure timestamp
