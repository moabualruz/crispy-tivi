---
name: crispy-qa-fix-plan
description: Generate a prioritized fix plan from CrispyTivi Flutter QA analysis results. Groups issues by root cause, identifies affected Dart/Flutter files, estimates complexity. Use when asked to "plan fixes", "fix QA issues", "what to fix next", "prioritize bugs", "create fix plan". Triggers on: fix plan, QA fix, prioritize issues, plan repairs.
---

# QA Fix Plan Generator — CrispyTivi Flutter

Turn QA issues into an actionable, prioritized implementation plan grouped by root cause.

## Steps

1. **Load latest issues:**
   - Determine which pipeline to use (ask user or default to most recently run)
   - Read `test/output/{pipeline}/{latest}/analysis/issues.json`
   - If `issues.json` is absent, run `/crispy-qa-analyze` first, then return here

2. **Load context files:**
   - Read `F:/work/crispi-tv-flutter/.ai/planning/USER-JOURNEYS.md` — to understand what each broken journey should do
   - Read `F:/work/crispi-tv-flutter/.ai/crispy_tivi_design_spec.md` — for design violation fixes

3. **Classify each issue (MANDATORY before grouping):**

   Every issue MUST be classified as one of:
   - **PRODUCTION BUG** — broken code in `lib/` (providers/, services/, screens/, data/)
   - **WIDGET BUG** — broken layout/styling in Flutter widget files
   - **RUST CORE BUG** — broken logic in `rust/crates/crispy-core/` (parsers, sync, DB)
   - **TEST HARNESS BUG** — broken test setup in `test/` or `integration_test/`
   - **SPEC GAP** — feature not implemented yet (no code exists)

   **Priority order:** PRODUCTION > WIDGET > RUST CORE > SPEC GAP > TEST HARNESS

   **Rule:** NEVER fix a TEST HARNESS bug if a PRODUCTION BUG causes the same symptom. If Movies screen is empty, check provider state and data flow BEFORE touching test fixtures.

4. **Group issues by root cause:**
   Issues that share the same root cause must be grouped into ONE fix item. Fixing the root once resolves all symptoms.

   Common root cause groupings:
   - "All focus states invisible" → single missing focus decoration in a shared widget
   - "All poster images blank" → single missing HTTP timeout or broken image loader
   - "Navigation goes to wrong screen" → single `onTap` / route handler wired to wrong destination
   - "All VOD screens empty after sync" → provider not calling `notifyListeners()` or state not updating

   ### Scroll/List Issues
   If the issue involves empty lists, missing items, or scroll not working:
   - Check the relevant provider — is `state` being set with actual data?
   - Check widget — is `ListView.builder` / `GridView` subscribed to the correct provider?
   - Check `itemCount` — is it driven by the live data list length?
   - NEVER add manual pagination or "load more" — all content is scroll-event driven

5. **For each root cause group, produce a fix item:**
   ```markdown
   ### FIX-{n}: {short title}
   **Root Cause:** {specific code problem}
   **Affected Journeys:** journey-01, journey-05, journey-12
   **Affected Screenshots:** {count} screenshots across {count} journeys
   **Files to Modify:**
   - `lib/providers/{provider}.dart` — {what to change}
   - `lib/screens/{screen}.dart` — {what to change}
   - `lib/widgets/{widget}.dart` — {what to change}
   **Rust Core (if applicable):**
   - `rust/crates/crispy-core/src/{module}.rs` — {what to change}
   **Estimate:** S / M / L  (S = <1hr, M = 1–4hr, L = 4–8hr)
   **Test:** After fix, re-run `CRISPY_PIPELINE=stub flutter test test/golden/`
   ```

6. **Prioritize fix items:**
   Order strictly as:
   1. **Critical** — user flow completely blocked (can't navigate, can't play)
   2. **Data bugs** — content not rendering (empty lists, blank cards, wrong titles)
   3. **Focus/navigation bugs** — D-pad/keyboard navigation broken or inconsistent
   4. **Design violations** — wrong colors, fonts, spacing, missing glass effects
   5. **Performance issues** — slow steps, excessive load times
   6. **Polish** — minor visual inconsistencies, animation glitches

7. **Write plan file:**
   Save to `F:/work/crispi-tv-flutter/.ai/planning/plans/YYYY-MM-DD-qa-fixes.md`:
   ```markdown
   # QA Fix Plan — {date}

   **Source:** {pipeline} run at {timestamp}
   **Total issues:** {n} across {m} journeys
   **Estimated total:** {sum of estimates}

   ## Fix Items (priority order)

   {fix items from step 5}

   ## Verification Plan
   After all fixes:
   1. `flutter analyze` — zero warnings
   2. `flutter test` — all unit/widget tests green
   3. `CRISPY_PIPELINE=stub flutter test test/golden/` — golden tests pass
   4. `cargo clippy --workspace -- -D warnings` — Rust core clean
   5. `/crispy-qa-track` — confirm all previously failing journeys now pass
   6. `/crispy-screenshot-approve` — update golden baselines if all pass
   ```

8. **Suggest execution:**
   "Plan written to `.ai/planning/plans/YYYY-MM-DD-qa-fixes.md`. Run `/superpowers:executing-plans` on it to begin implementing the fixes."
