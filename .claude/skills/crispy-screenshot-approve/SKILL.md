---
name: crispy-screenshot-approve
description: Approve or reject CrispyTivi Flutter golden test changes. Updates golden baselines in test/golden/goldens/ after human verification. Use when asked to "approve screenshots", "accept visual changes", "update golden baselines", "lock in screenshots". Triggers on: approve screenshots, update baselines, accept visual changes.
---

# Screenshot Approve/Reject Workflow — CrispyTivi Flutter

## Steps

1. **Check for existing review:**
   - If `/crispy-screenshot-review` was already run this session, use those results
   - Otherwise, run `/crispy-screenshot-review` first

2. **Process each classified screenshot:**

   For **IMPROVEMENT** (auto-approve):
   ```bash
   # Regenerate just this golden file
   flutter test test/golden/{journey_test}.dart --update-goldens
   ```

   For **REGRESSION** (auto-reject):
   - Do NOT update the golden — the test failure is correct behavior
   - File a bug: "This regression must be fixed in production code before approving"
   - Note the rejection reasoning

   For **NEUTRAL** (ask user):
   - Show the screenshot to the user
   - Ask: "This screenshot changed but seems neither better nor worse. Approve?"
   - If yes: `flutter test test/golden/{test}.dart --update-goldens`
   - If no: leave golden as-is, file for investigation

   For **SPEC_VIOLATION** (do NOT approve):
   - Flag: "This screenshot doesn't match the spec. Code fix needed, not approval."
   - Do NOT run `--update-goldens`

3. **Commit updated golden files:**
   ```bash
   git add test/golden/goldens/
   git commit -m "test: update golden baselines after visual review"
   ```

4. **Print summary:**
   ```
   Approved: X | Rejected: Y | Needs Fix: Z | Human Review: W
   ```

### Approval Guards
- NEVER approve screenshots that mask production bugs — if test data was modified to make screenshots pass, verify production code path works first
- After approving new baselines, re-run stub pipeline once to confirm stability: `flutter test test/golden/`
- NEVER approve screenshots that violate the design spec — run `/crispy-screenshot-design-audit` first
- Flutter golden files are binary PNGs committed to git — keep diffs clean by approving only genuine improvements
