---
name: crispy-screenshot-design-audit
description: Audit ALL CrispyTivi screenshots against the design spec for compliance. Checks every screen for glassmorphic surfaces, focus states, Outfit/Inter typography, brand accent gradient, nav bar layout, and Theme token usage. Use when asked to "audit design compliance", "check screenshots against design", "visual design review", "design token compliance". Triggers on: design audit, design compliance, visual design check, token compliance.
---

# Visual Design Compliance Audit — CrispyTivi

Audit ALL screenshots (not just failures) against the CrispyTivi design specification.

## Steps

1. **Load context:**
   - Read `rust/crates/crispy-ui/tests/output/{pipeline}/runs-index.json` → latest manifest
   - Read `F:/work/crispy-tivi/.ai/crispy_tivi_design_spec.md` — full design rules
   - Read `F:/work/crispy-tivi/.impeccable.md` — design context and principles
   - Read `F:/work/crispy-tivi/rust/crates/crispy-ui/ui/globals/theme.slint` — design tokens

2. **For each screenshot in manifest (ALL, not just failures):**
   a. View the screenshot PNG (Read tool — multimodal)
   b. Check against design rules:
      - **Dark-first glassmorphic:** surfaces use `rgba(28,28,32,0.8)` with `1px rgba(255,255,255,0.1)` border?
      - **Focus states:** focused element has pure white ring (`2px solid rgba(255,255,255,0.5)` + `rgba(255,255,255,0.1)` bg)?
      - **Typography:** headings use Outfit (700-800 weight, large), body uses Inter (400-600, clean)?
      - **Cards:** `border-radius: 12px`, glass surface, focus scale + white border glow?
      - **Brand accent:** `#FF4B2B → #FF416C` gradient ONLY on progress bars and live badges?
      - **Nav bar:** pill-shaped items (`border-radius: 20px`), correct layout (profile → nav items → search pill)?
      - **OSD:** circular `50px` glass buttons, gradient bottom overlay?
      - **Spacing:** consistent use of Theme spacing tokens, not cramped or too loose?
      - **Color palette:** primary text `rgba(255,255,255,0.95)`, secondary `rgba(255,255,255,0.60)`, surfaces dark?
      - **No hardcoded values:** check that all styles come from Theme tokens, not raw rgba/px values?
   c. Rate compliance: COMPLIANT / MINOR_VIOLATION / MAJOR_VIOLATION
   d. Note specific violations with exact design rule reference and the Theme token that should be used

3. **Output design audit report:**
   ```
   ## Design Compliance Audit — {run_id}

   Overall: X% compliant | Y minor violations | Z major violations

   ### Major Violations
   | Screenshot | Rule Violated | Expected (Token) | Actual |
   |------------|--------------|-----------------|--------|

   ### Minor Violations
   | Screenshot | Rule Violated | Description |

   ### Per-Journey Compliance
   | Journey | Screenshots | Compliant | Violations |
   ```

4. Suggest fixes for each major violation with the specific Theme token from `rust/crates/crispy-ui/ui/globals/theme.slint` that should replace the hardcoded value.

### Theme Token Validation
Before auditing screenshots, read `rust/crates/crispy-ui/ui/globals/theme.slint` to get the complete token list. Check every screenshot for:
- Colors: all must use `Theme.text-primary`, `Theme.surface`, etc. — no hardcoded `rgba()` or `#hex`
- Fonts: must use `Theme.font-display` (Outfit) or `Theme.font-body` (Inter) — no raw font names
- Spacing: must use `Theme.spacing-xs/sm/md/lg/xl` — no raw px values
- Radii: must use `Theme.radius-sm/md/lg/pill` — no raw border-radius
- Focus: every interactive element must have `Theme.focus-ring` border on focus
