# UI/UX Remediation & State Binding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute this plan task-by-task.

**Goal:** Eradicate "AI Slop" visual regressions, harden onboarding layouts to prevent collapse, rebuild master category views as math-based grids, and investigate/fix non-UI state binding bugs (EPG/Channels) using subagents.

**Architecture:** We will refine Slint UI files incrementally using absolute layout guards (`min-width`) and mathematically structured `GridLayout`s. For state issues and logic bugs, we will deploy investigation subagents to trace Rust `main.rs` memory passing to Slint.

**Tech Stack:** Slint UI, Rust (Tokio)

---
### Task 1: Harden Onboarding Layout Convergence
**Required Impeccable Skill:** `i-harden` (Improve interface resilience and edge case management)
**Files:**
- Modify: `rust/crates/crispy-ui/ui/screens/onboarding.slint`

**Step 1: Write the failing test / visual verification**
*(Manually resize window down to 400px wide. Observe text garbling and form overlap).*

**Step 2: Write minimal implementation**
Wrap the Onboarding form content (or the inner layouts) in a container with a strict `min-width: 480px` and ensure the `ScrollView` tracks `viewport-width: root.width`. Update the "Checkmark" Z-index math to ensure it doesn't overlap the wizard dots.

**Step 3: Verify & Commit**
```bash
cargo check -p crispy-ui
git add rust/crates/crispy-ui/ui/screens/onboarding.slint
git commit -m "fix(ui): harden onboarding layout boundaries to prevent collapse"
```

---
### Task 2: Purge Vibrant Aesthetics (The "Egg" Fix)
**Required Impeccable Skill:** `i-quieter` (Tone down overly visually aggressive designs) & `i-polish`
**Files:**
- Modify: `rust/crates/crispy-ui/ui/components/action-button.slint`
- Modify: `rust/crates/crispy-ui/ui/components/filter-chip.slint`
- Modify: `rust/crates/crispy-ui/ui/components/profile-button.slint`

**Step 1: Write minimal implementation**
Replace all uses of `Theme.accent-gradient` on primary component backgrounds with frosted glass `rgba(255,255,255, 0.1)` or pure white `Theme.btn-primary-bg`. Adjust extreme `border-radius: height/2` pills to a standard architectural `Theme.radius-md` (8px).

**Step 2: Verify & Commit**
```bash
cargo check -p crispy-ui
git add .
git commit -m "style(ui): remove vibrant AI slop gradients from core components"
```

---
### Task 3: Architect Master Category Grids
**Required Impeccable Skill:** `i-arrange` (Improve layout, spacing, and structural grids)
**Files:**
- Modify: `rust/crates/crispy-ui/ui/screens/movies.slint`
- Modify: `rust/crates/crispy-ui/ui/screens/series.slint`

**Step 1: Write minimal implementation**
Replace the single generic `HorizontalLayout` lane with a mathematical `GridLayout`. Calculate `row: floor(idx / 5)` and `col: mod(idx, 5)` on the standard `for item[idx] in array` Slint loops to force horizontal wrapping and form a dense TV library grid.

**Step 2: Verify & Commit**
```bash
cargo check -p crispy-ui
git add .
git commit -m "feat(ui): implement dense mathematical wrapping grids for VOD libraries"
```

---
### Task 4: Add Empty State Affordances to Media Cards
**Required Impeccable Skill:** `i-delight` (Add moments of joy / empty state guidance)
**Files:**
- Modify: `rust/crates/crispy-ui/ui/components/vod-card.slint`

**Step 1: Write minimal implementation**
Inject an `IconMovie` or `IconTv` Vector/SVG graphic inside the `VodCard` image placeholder `Rectangle`. Set opacity to 20% so it renders as a deliberate "missing media" empty state rather than a broken layout box.

**Step 2: Verify & Commit**
```bash
cargo check -p crispy-ui
git add .
git commit -m "feat(ui): add graceful empty state vectors to VOD cards"
```

---
### Task 5: Investigate EPG & Channel State Binding (Non-UI Backend)
**Required Superpower Skill:** `code-review-excellence` & `subagent-driven-development`
**Files:**
- Target Analysis: `rust/crates/crispy-ui/src/main.rs`, `rust/crates/crispy-ui/src/data_engine/`

**Step 1: Dispatch Investigation Subagent**
Instruct the subagent: *"Act as a code-review-excellence debugger. Analyze the Slint to Rust event bridge array mapping for Channels and EPG. Why does the UI group list not sync with the loaded M3U channels seen in the demo? Locate the desync logic in the Rust data bindings."*

**Step 2: Implement Backend Fix**
Apply the specific Rust backend or Slint `.on-` callback fixes discovered by the subagent to ensure category indexing is passed and flushed to the UI arrays accurately.

**Step 3: Verify & Commit**
```bash
cargo run -p crispy-ui
git add .
git commit -m "fix(backend): patch channel/EPG state binding desync"
```
