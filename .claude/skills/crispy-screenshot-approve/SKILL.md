---
name: crispy-screenshot-approve
description: Approve or reject CrispyTivi screenshot changes using the review pipeline. Updates golden baselines in rust/crates/crispy-ui/tests/golden/ after human verification. Use when asked to "approve screenshots", "accept visual changes", "update golden baselines", "lock in screenshots". Triggers on: approve screenshots, update baselines, accept visual changes.
---

# Screenshot Approve/Reject Workflow — CrispyTivi

## Steps

1. **Check for existing review:**
   - If `/crispy-screenshot-review` was already run this session, use those results
   - Otherwise, run `/crispy-screenshot-review` first

2. **Process each classified screenshot:**

   For **IMPROVEMENT** (auto-approve):
   ```bash
   cargo run -p crispy-ui --bin screenshot-review -- approve {id}
   ```

   For **REGRESSION** (auto-reject):
   ```bash
   cargo run -p crispy-ui --bin screenshot-review -- reject {id} --note "{reasoning from review}"
   ```

   For **NEUTRAL** (ask user):
   - Show the screenshot to the user
   - Ask: "This screenshot changed but seems neither better nor worse. Approve?"
   - Execute approve or reject based on response

   For **SPEC_VIOLATION** (do NOT approve):
   - Flag: "This screenshot doesn't match the spec. Code fix needed, not approval."
   - Do NOT run approve command

3. **Commit updated golden files:**
   ```bash
   git add rust/crates/crispy-ui/tests/golden/
   git commit -m "test: update golden baselines after visual review"
   ```

4. **Print summary:**
   ```
   Approved: X | Rejected: Y | Needs Fix: Z | Human Review: W
   ```
