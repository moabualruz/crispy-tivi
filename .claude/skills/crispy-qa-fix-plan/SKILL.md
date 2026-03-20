---
name: crispy-qa-fix-plan
description: Generate a prioritized fix plan from CrispyTivi QA analysis results. Groups issues by root cause, identifies affected Rust/Slint files, estimates complexity. Use when asked to "plan fixes", "fix QA issues", "what to fix next", "prioritize bugs", "create fix plan". Triggers on: fix plan, QA fix, prioritize issues, plan repairs.
---

# QA Fix Plan Generator — CrispyTivi

Turn QA issues into an actionable, prioritized implementation plan grouped by root cause.

## Steps

1. **Load latest issues:**
   - Determine which pipeline to use (ask user or default to most recently run)
   - Read `rust/crates/crispy-ui/tests/output/{pipeline}/{latest}/analysis/issues.json`
   - If `issues.json` is absent, run `/crispy-qa-analyze` first, then return here

2. **Load context files:**
   - Read `F:/work/crispy-tivi/.ai/planning/USER-JOURNEYS.md` — to understand what each broken journey should do
   - Read `F:/work/crispy-tivi/.ai/crispy_tivi_design_spec.md` — for design violation fixes

3. **Classify each issue (MANDATORY before grouping):**

   Every issue MUST be classified as one of:
   - **PRODUCTION BUG** — broken code in `src/` (event_bridge.rs, data_engine.rs, sync_task.rs, scroll_integration.rs)
   - **UI MARKUP BUG** — broken layout/styling in `.slint` files
   - **TEST HARNESS BUG** — broken test setup in `tests/harness/` (db.rs, renderer.rs, journey files)
   - **SPEC GAP** — feature not implemented yet (no code exists)

   **Priority order:** PRODUCTION > UI > SPEC GAP > TEST HARNESS

   **Rule:** NEVER fix a TEST HARNESS bug if a PRODUCTION BUG causes the same symptom. If Movies screen is empty, check `event_bridge.rs` scroll callbacks and `ScrollBridge.set_total()` BEFORE touching `populate_ui()` in db.rs.

4. **Group issues by root cause:**
   Issues that share the same root cause (same missing callback wiring, same incorrect Slint property, same unset data field) must be grouped into ONE fix item — not treated as separate items. Fixing the root once resolves all symptoms.

   Common root cause groupings:
   - "All focus states invisible" → single missing `Theme.focus-ring` application in a shared component
   - "All poster images blank" → single missing HTTP timeout or broken image loader
   - "Navigation goes to wrong screen" → single `on_selected` callback wired to wrong handler
   - "All VOD screens empty after sync" → `ScrollBridge.set_total()` never called (production bug, not test data)

   ### Scroll/Viewport Issues
   If the issue involves empty lists, missing items, or scroll not working:
   - Check `scroll_integration.rs` — is `ScrollBridge.set_total()` called with actual data length?
   - Check `event_bridge.rs` — do `on_scroll_xxx` callbacks handle delta==0 (forced repopulate)?
   - Check `.ai/slint-crispy-vscroll/spec/` for correct usage patterns
   - NEVER reimplement scroll logic — always use ScrollBridge

5. **For each root cause group, produce a fix item:**
   ```markdown
   ### FIX-{n}: {short title}
   **Root Cause:** {specific code problem}
   **Affected Journeys:** journey-01, journey-05, journey-12
   **Affected Screenshots:** {count} screenshots across {count} journeys
   **Files to Modify:**
   - `rust/crates/crispy-ui/src/{file}.rs` — {what to change}
   - `rust/crates/crispy-ui/ui/{component}.slint` — {what to change}
   **Estimate:** S / M / L  (S = <1hr, M = 1–4hr, L = 4–8hr)
   **Test:** After fix, re-run `CRISPY_PIPELINE=stub cargo test -p crispy-ui --test screenshots`
   ```

6. **Prioritize fix items:**
   Order strictly as:
   1. **Critical** — user flow completely blocked (can't navigate, can't play)
   2. **Data bugs** — content not rendering (empty lists, blank cards, wrong titles)
   3. **Focus/navigation bugs** — D-pad broken or inconsistent
   4. **Design violations** — wrong colors, fonts, spacing, missing glass effects
   5. **Performance issues** — slow steps, excessive load times
   6. **Polish** — minor visual inconsistencies, animation glitches

7. **Write plan file:**
   Save to `F:/work/crispy-tivi/.ai/planning/plans/YYYY-MM-DD-qa-fixes.md`:
   ```markdown
   # QA Fix Plan — {date}

   **Source:** {pipeline} run at {timestamp}
   **Total issues:** {n} across {m} journeys
   **Estimated total:** {sum of estimates}

   ## Fix Items (priority order)

   {fix items from step 4}

   ## Verification Plan
   After all fixes:
   1. `cargo fmt --all && cargo clippy --workspace -- -D warnings`
   2. `CRISPY_PIPELINE=stub cargo test -p crispy-ui --test screenshots`
   3. `/crispy-qa-track` — confirm all previously failing journeys now pass
   4. `/crispy-screenshot-approve` — update golden baselines if all pass
   ```

8. **Suggest execution:**
   "Plan written to `.ai/planning/plans/YYYY-MM-DD-qa-fixes.md`. Run `/superpowers:executing-plans` on it to begin implementing the fixes."
