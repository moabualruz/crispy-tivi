---
name: crispy-screenshot-review
description: AI reviews CrispyTivi screenshot test failures against journey specs and design docs. Classifies each failure as regression, improvement, neutral, or spec violation. Use when asked to "review screenshots", "check visual regressions", "review test run", "what broke visually", "analyze screenshot failures". Triggers on: review screenshots, screenshot failures, visual regression review.
---

# AI Screenshot Review — CrispyTivi

Review screenshot test failures by comparing actual renders against journey specifications and design documents.

## Steps

1. **Load test run data:**
   - Read `rust/crates/crispy-ui/tests/output/{pipeline}/runs-index.json` to find latest run
   - Read `{latest_path}/manifest.json`

2. **Load design context:**
   - Read `F:/work/crispy-tivi/.ai/crispy_tivi_design_spec.md` for visual design rules
   - Read `F:/work/crispy-tivi/.impeccable.md` for design context
   - Read `F:/work/crispy-tivi/.ai/planning/USER-JOURNEYS.md` for journey definitions

3. **For each `fail` screenshot in manifest:**
   a. Read the `test` PNG file (using Read tool — Claude is multimodal)
   b. Read the `golden` PNG file for comparison
   c. Read the `diff` PNG file to see what changed
   d. Read `journey_step` and `journey_expectation` from manifest
   e. Compare what you SEE in the screenshot against:
      - What the journey spec says SHOULD happen at this step
      - What the design spec says the UI SHOULD look like
   f. Classify as one of:
      - **REGRESSION** — golden was correct, test is worse (recommend reject)
      - **IMPROVEMENT** — golden was wrong, test is better/closer to spec (recommend approve)
      - **NEUTRAL** — visual change, neither better nor worse (recommend human review)
      - **SPEC_VIOLATION** — neither golden nor test matches the spec (recommend fix code)

4. **For each `new` screenshot:**
   a. View the screenshot
   b. Compare against design spec and journey expectations
   c. Classify as ACCEPTABLE or SPEC_VIOLATION

5. **Output structured review:**

   ```
   ## Screenshot Review — {run_id}

   | Screenshot | Classification | Action | Reasoning |
   |------------|---------------|--------|-----------|
   | j01/003_source_form | REGRESSION | reject | Form fields overlap — was correct in golden |
   | j05/007_focus_ring | IMPROVEMENT | approve | Focus ring now matches Theme.focus-ring spec |

   ### Regressions (fix before approving)
   [Details for each regression with likely cause]

   ### Spec Violations (fix code)
   [Details with exact spec reference that's violated]
   ```

6. **Cross-reference git changes:**
   - For regressions, check `git log --oneline -10` for recent changes
   - Identify which commit likely caused the regression

7. Suggest next steps:
   - If regressions found: "Fix the regressions, then re-run `/crispy-screenshot-run`"
   - If only improvements: "Run `/crispy-screenshot-approve` to accept improvements"
