---
name: rice-screenshot-design-audit
description: Audit ALL screenshots against design spec for compliance. Use when asked to "audit design compliance", "check screenshots against design", "visual design review", "design token compliance".
---

# Visual Design Compliance Audit

Audit ALL screenshots (not just failures) against the CrispyTivi design specification.

## Steps

1. **Load context:**
   - Read `rust/crates/crispy-ui/tests/runs/runs-index.json` → latest manifest
   - Read `.ai/crispy_tivi_design_spec.md` — full design rules
   - Read `.impeccable.md` — design context and principles
   - Read `rust/crates/crispy-ui/ui/globals/theme.slint` — design tokens

2. **For each screenshot in manifest (ALL, not just failures):**
   a. View the screenshot PNG (Read tool — multimodal)
   b. Check against design rules:
      - **Dark-first glassmorphic:** surfaces use dark glass bg with subtle border?
      - **Focus states:** focused element has pure white ring (2px+)?
      - **Typography:** headings look like Outfit (large, bold), body like Inter (clean, legible)?
      - **Cards:** correct border-radius, glass surface, focus glow?
      - **Brand accent:** gradient only on progress bars and live badges?
      - **Nav bar:** pill-shaped items, correct layout?
      - **OSD:** circular glass buttons, auto-hide indicators?
      - **Spacing:** consistent, not cramped or too loose?
      - **Color palette:** primary text white 95%, secondary 60%, surfaces dark?
   c. Rate compliance: COMPLIANT / MINOR_VIOLATION / MAJOR_VIOLATION
   d. Note specific violations with exact design rule reference

3. **Output design audit report:**
   ```
   ## Design Compliance Audit — {run_id}

   Overall: X% compliant | Y minor violations | Z major violations

   ### Major Violations
   | Screenshot | Rule Violated | Description |
   |------------|--------------|-------------|

   ### Minor Violations
   | Screenshot | Rule Violated | Description |

   ### Per-Journey Compliance
   | Journey | Screenshots | Compliant | Violations |
   ```

4. Suggest fixes for each major violation with specific design token references.
