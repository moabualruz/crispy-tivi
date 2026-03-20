---
name: crispy-screenshot-design-audit
description: Audit ALL CrispyTivi Flutter screenshots against the design spec for compliance. Checks every screen for glassmorphic surfaces, focus states, Outfit/Inter typography, brand accent gradient, nav bar layout, and Theme token usage. Use when asked to "audit design compliance", "check screenshots against design", "visual design review", "design token compliance". Triggers on: design audit, design compliance, visual design check, token compliance.
---

# Visual Design Compliance Audit — CrispyTivi Flutter

Audit ALL screenshots (not just failures) against the CrispyTivi design specification.

## Steps

1. **Load context:**
   - Read `test/output/{pipeline}/runs-index.json` → latest manifest
   - Read `F:/work/crispi-tv-flutter/.ai/crispy_tivi_design_spec.md` — full design rules
   - Read `F:/work/crispi-tv-flutter/.impeccable.md` — design context and principles
   - Read `F:/work/crispi-tv-flutter/lib/theme/app_theme.dart` — Flutter design tokens

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
      - **Spacing:** consistent use of AppTheme spacing tokens, not cramped or too loose?
      - **Color palette:** primary text `rgba(255,255,255,0.95)`, secondary `rgba(255,255,255,0.60)`, surfaces dark?
      - **No hardcoded values:** check that all styles come from `AppTheme` tokens, not raw `Color(0xFF...)` or magic numbers?
   c. Rate compliance: COMPLIANT / MINOR_VIOLATION / MAJOR_VIOLATION
   d. Note specific violations with exact design rule reference and the `AppTheme` token that should be used

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

4. Suggest fixes for each major violation with the specific `AppTheme` token from `lib/theme/app_theme.dart` that should replace the hardcoded value.

### Theme Token Validation
Before auditing screenshots, read `lib/theme/app_theme.dart` to get the complete token list. Check every screenshot for:
- Colors: all must use `AppTheme.textPrimary`, `AppTheme.surface`, etc. — no raw `Color(0xFF...)` or hex strings
- Fonts: must use `AppTheme.fontDisplay` (Outfit) or `AppTheme.fontBody` (Inter) — no raw `fontFamily` strings
- Spacing: must use `AppTheme.spacingXs/Sm/Md/Lg/Xl` — no raw `EdgeInsets` with magic numbers
- Radii: must use `AppTheme.radiusSm/Md/Lg/Pill` — no raw `BorderRadius` values
- Focus: every interactive widget must apply `AppTheme.focusRing` decoration on focus
