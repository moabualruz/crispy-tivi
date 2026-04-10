# CrispyTivi Design System

This document records the current editable design-system surface. Flutter
tokens and widgets remain authoritative; Penpot mirrors them as editable
design artifacts.

## Penpot

The local Penpot file contains a page named `CrispyTivi Design System`.
It replaces the earlier inventory/screenshot boards with editable shapes.

Current boards:

- `FOUNDATION - Tokens`
- `COMPONENT - Core Components`
- `COMPONENT - Buttons`
- `COMPONENT - Badges`
- `COMPONENT - Chips`
- `COMPONENT - Headers`
- `COMPONENT - Surfaces`
- `COMPONENT - State Widgets`
- `COMPONENT - Skeletons`
- `COMPONENT - Media Cards`
- `COMPONENT - TV Controls`
- `PATTERN - Navigation and TV Focus`
- `PATTERN - EPG Timeline`
- `PATTERN - Player OSD`
- `SCREEN - Representative Layouts`
- `FEATURE - Live TV Widgets`
- `FEATURE - Settings Widgets`
- `FEATURE - VOD Widgets`
- `FEATURE - Player Widgets`
- `ASSET - Brand Assets`

Boards are laid out in a visible 3-column grid. Core component category boards
exist as first-class Penpot boards so Widgetbook `designLink` values resolve to
real board names instead of broad overview substitutes.

The publisher clears all shapes from the active design-system page before
rebuilding these boards, so stale inventory/orphan shapes cannot sit over the
design system. Boards use distinct tinted backgrounds so they remain visually
separable in the Penpot overview zoom.

The Penpot local library contains an active token set named `CrispyTivi` with
45 Penpot color/spacing/radius tokens, plus editable foundation specimens for Flutter typography,
elevation, and motion tokens that do not map cleanly to the local Penpot token
API.

Latest read-back evidence:

- Page: `CrispyTivi Design System`
- Active token set: `CrispyTivi` (`45` Penpot color/spacing/radius tokens)
- Editable boards: `20`
- Duplicate active board names: `0`
- Widgetbook-linked boards: `19`
- Uploaded brand assets: `2`
- Board layout: `20` unique board positions; every board has visible children.
- Active page cleanup: no non-design-system orphan shapes remain on the active
  page after publish.

Older generated inventory pages are renamed with `ARCHIVE -` in Penpot. They
are not the design-system source.

## Widgetbook

Widgetbook uses official `@widgetbook.UseCase` annotations from
`widgetbook_annotation`.

Coverage matrix:

- `design/docs/widgetbook-coverage.md`
- Generator: `scripts/design/generate_widgetbook_coverage.py`

Use cases are split by file:

- `app/flutter/lib/widgetbook/foundation_use_cases.dart`
- `app/flutter/lib/widgetbook/core_widget_use_cases.dart`
- `app/flutter/lib/widgetbook/feature_widget_use_cases.dart`
- `app/flutter/lib/widgetbook/player_widget_use_cases.dart`
- `app/flutter/lib/widgetbook/catalog_surface.dart`

The runtime catalog remains `app/flutter/lib/widgetbook.dart`.

## Coverage

Covered now:

- Color, spacing, and radius token specimens.
- Typography, elevation, and motion token specimens.
- Buttons.
- Live/content badges.
- Metadata and genre chips.
- Section headers.
- Glass surfaces.
- Empty/loading/error states.
- Skeleton loading states.
- Generated media placeholders.
- Watch progress.
- TV color button legend.
- Feature fixtures for `ChannelListItem`, `ChannelGridItem`, `SettingsBadge`,
  and `SettingsCard`.
- Feature fixtures for `QualityBadge`, `CircularAction`, `EpisodeTile`, and
  `ExpandableSynopsis`.
- Player fixtures for `OsdIconButton`, subtitle controls, and subtitle preview.
- Brand asset board with checked-in Flutter logo artwork uploaded to Penpot.

Still needed:

- Fixture-backed Widgetbook use cases for remaining provider-heavy feature
  widgets.
- Penpot component variants for page-level patterns after fixtures exist.
- More real artwork/imagery for media-card examples once asset licensing/source
  is settled.
- Golden coverage for Cloud Browser, Multiview, profile management, VOD
  details, media-server login, and series browser.
