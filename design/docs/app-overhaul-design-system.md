# CrispyTivi App Overhaul Design System

This branch starts the vNext app-wide visual system. It is intentionally
separate from the shipped `Crispy*` tokens until screens are migrated and
validated in Widgetbook + Penpot.

## Product direction

- TV-first, remote-safe interaction: focus states must be obvious from across a
  room.
- Cinematic but readable: dark surfaces remain, but panels use clearer elevation
  separation and less pure-black stacking.
- Code/design parity: every token must exist in Flutter, JSON, and Penpot before
  it is used in app UI.
- Progressive migration: add vNext surfaces beside existing Crispy tokens, then
  migrate high-value screens one route at a time.

## vNext token sources

- Flutter: `app/flutter/lib/core/theme/crispy_overhaul_tokens.dart`
- JSON: `design/tokens/crispy-overhaul.tokens.json`
- Penpot publisher: `design/penpot/publish_app_overhaul_design_system.js`

## Token summary

- Surface: `void`, `panel`, `raised`, `glass`
- Accent: `focus`, `brand`, `brandSoft`, `actionBlue`
- Semantic: `success`, `warning`, `danger`
- Text: `primary`, `secondary`, `muted`
- Spacing: `hairline`, `compact`, `small`, `medium`, `large`, `section`, `screen`
- Radius: `sharp`, `card`, `sheet`, `pill`
- Motion: `focus`, `panel`, `page`

## Migration gates

1. Publish vNext foundations to Penpot.
2. Add Widgetbook vNext token/specimen use cases.
3. Migrate app shell/navigation first.
4. Migrate settings and player controls second.
5. Migrate media rails/cards third.
6. Keep old and vNext tokens side-by-side until all target screens pass visual QA.

## Verification

- `dart format app/flutter/lib/core/theme/crispy_overhaul_tokens.dart app/flutter/lib/core/theme/theme.dart`
- `dart analyze app/flutter/lib/core/theme/crispy_overhaul_tokens.dart app/flutter/lib/core/theme/theme.dart`
- JSON parse for `design/tokens/crispy-overhaul.tokens.json`
- Penpot publish/read-back for vNext boards when the plugin is connected.
