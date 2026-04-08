# AGENTS.md — CrispyTivi Workspace Guidance

## Intent

Work directly in this repository without relying on any external `.ai` folder or
submodule. Use only checked-in project files as context.

## Operating Rules

- Finish the task end-to-end when it is safe to do so.
- Verify claims with tests, diagnostics, or direct inspection before reporting
  completion.
- Keep product paths pagination-first for browsing, search, and catalog screens.
- Prefer deletion or simplification over layering in extra abstractions.
- Do not add new dependencies unless clearly necessary.

## Project Boundaries

- Rust owns backend logic, sync, parsing, validation, and persistence-heavy
  behavior.
- Flutter owns UI, navigation, interactions, and platform presentation.
- Shared design tokens live under `app/flutter/lib/core/theme/`.
- Shared reusable widgets live under `app/flutter/lib/core/widgets/`.

## Preferred Verification

- `flutter analyze`
- targeted `flutter test` for touched Dart code
- `cd app/flutter && flutter test integration_test/main_test.dart -d linux` for native aggregate coverage
- `./scripts/android/run_emulator_integration.sh <suite>` for Android emulator coverage
- targeted Rust tests when Rust code changes

## Commit Rules

- Use Lore-style commit messages.
- Report what was verified and what remains unverified.
- Do not commit local-only state, generated noise, or secret credential files.

## Documentation Rules

- Keep `CLAUDE.md`, `AGENTS.md`, checked-in docs, and executable tests aligned.
- Do not introduce new references to a `.ai` folder.
