# CLAUDE.md — Project Context for CrispyTivi

## Summary

CrispyTivi is a cross-platform IPTV and media streaming application.

- UI: Flutter + Riverpod
- Native/backend logic: Rust workspace under `rust/`
- Media: `media_kit`
- Persistence: SQLite via Dart and Rust layers
- Targets: Linux, Windows, Android phone/tablet/TV, iOS, Web

## Source Of Truth

The repository no longer depends on a separate `.ai` folder.

Use the checked-in project materials only:

- `.impeccable.md` for implementation and quality expectations
- `docs/` for project screenshots and checked-in documentation
- `integration_test/` and `test/` for executable behavior
- `rust/crates/crispy-core/` for backend/domain behavior
- existing theme tokens and widgets under `lib/core/`

If a feature is undocumented, treat the current code plus passing tests as the
authoritative baseline and update checked-in docs when you clarify behavior.

## Architecture Rules

- Put business logic, parsing, validation, sync, and persistence in Rust when it
  belongs below the UI boundary.
- Keep Flutter focused on presentation, interaction, routing, and platform UX.
- Do not duplicate backend logic in Dart when the Rust boundary is the right
  home for it.
- Keep browsing/search/list surfaces pagination-first. Do not route product code
  back through load-all state as a shortcut.

## UI Rules

- Reuse theme tokens from `lib/core/theme/`.
- Reuse shared widgets from `lib/core/widgets/` before inventing new ones.
- Preserve the project’s dark, utility-first visual language.
- On TV and remote-style surfaces, protect focus behavior and visibility.

## Testing Rules

- Prefer narrow, reliable tests over broad but flaky smoke coverage.
- Keep Linux native integration and Android emulator verification runnable.
- Use the checked-in Android runner script when emulator visibility matters:
  `scripts/android/run_emulator_integration.sh`
- When a test starts failing because the UI moved to pagination-backed behavior,
  fix the test to follow the real user path rather than regressing product code.

## Quality Commands

```bash
flutter analyze
flutter test
flutter test integration_test/main_test.dart -d linux
./scripts/android/run_emulator_integration.sh integration_test/main_test.dart
cd rust && cargo test
```

## Git Rules

- Keep commits intentional and scoped.
- Do not commit secrets, local credential overrides, or machine-specific state.
- Keep local noise out of the repo.
- Use Lore-style commit messages with explicit constraints, rejected options,
  verification, and known gaps.
