---
name: rice-screenshot-approve
description: Approve or reject screenshot changes using the review pipeline. Use when asked to "approve screenshots", "accept visual changes", "update golden baselines".
---

# Screenshot Approve/Reject Workflow

## Steps

1. **Check for existing review:**
   - If `/rice-screenshot-review` was already run this session, use those results
   - Otherwise, run `/rice-screenshot-review` first

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
