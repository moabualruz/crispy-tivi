---
name: widgetbook-design-system
description: Use when adding or fixing CrispyTivi Widgetbook design-system coverage, especially official per-widget @UseCase annotations, fixture-backed use cases, design links, and Widgetbook build verification.
---

# Widgetbook Design System Skill

Use this with `$design-system` for Widgetbook work.

## Official Pattern

Use `widgetbook_annotation`:

```dart
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: MyWidget,
  path: '[Core widgets]/MyWidget',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - MyWidget',
)
Widget myWidgetUseCase(BuildContext context) => const MyWidget();
```

## Repository Structure

- Runtime shell: `app/flutter/lib/widgetbook.dart`
- Shared wrapper: `app/flutter/lib/widgetbook/catalog_surface.dart`
- Foundation use cases: `app/flutter/lib/widgetbook/foundation_use_cases.dart`
- Core widget use cases: `app/flutter/lib/widgetbook/core_widget_use_cases.dart`
- Feature fixtures: `app/flutter/lib/widgetbook/feature_widget_use_cases.dart`
- Player fixtures: `app/flutter/lib/widgetbook/player_widget_use_cases.dart`

## Rules

1. One annotated use case per real widget or tight widget family.
2. Do not create broad "inventory map" use cases.
3. Create/update a widget coverage matrix for every public/reusable widget in:
   - `app/flutter/lib/core/widgets/`
   - `app/flutter/lib/core/navigation/`
   - `app/flutter/lib/features/*/presentation/widgets/`
   - `app/flutter/lib/features/*/presentation/screens/`
4. Every row must be one of:
   - `direct-use-case`
   - `family-use-case`
   - `deferred-provider-fixture`
   - `deferred-runtime-platform`
   - `private-helper`
5. Use stable fixture data; avoid provider-heavy widgets until dependencies are
   isolated with provider overrides or lightweight wrappers.
6. Every use case needs a Penpot `designLink` string.
7. The manual `Widgetbook.material` tree remains runtime entry unless generator
   adoption is explicitly planned.
8. Keep catalog examples visual and interactive, not documentation cards.

## Penpot Link Verification

- When Widgetbook use cases point to Penpot, verify the linked target file in
  the browser. Do not accept a link based only on board names in read-back.
- If Penpot boards are generated from Widgetbook coverage, confirm every linked
  board is visible at overview zoom and has visible child content inside the
  board bounds.
- If a direct use case is added, update both:
  - `design/docs/widgetbook-coverage.md`
  - the Penpot publisher board/link metadata

## Verification

Run after changes:

```bash
dart format app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart
dart analyze app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart
scripts/design/check_design_tokens.sh
scripts/design/build_widgetbook.sh
```

Known acceptable build warnings:

- Flutter web wasm dry-run warning from `flutter_rust_bridge`.
- Icon font tree-shaking warning.
