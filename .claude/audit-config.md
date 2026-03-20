# CrispyTivi Audit Configuration — Flutter + Rust Core

## Project Type
- **Language:** Dart (Flutter) + Rust (crispy-core via FFI)
- **UI Framework:** Flutter (Material 3, Riverpod)
- **State Management:** Riverpod (providers, notifiers)
- **Database:** sqflite (Dart) + rusqlite (Rust)
- **Video:** media_kit

## UI Files
- **Screens:** `lib/features/*/presentation/screens/`
- **Widgets:** `lib/features/*/presentation/widgets/`
- **Theme:** `lib/core/theme/app_theme.dart`
- **Design Tokens:** `CrispySpacing`, `CrispyRadius`, `CrispyAnimation`, `ColorScheme`

## State Management
- **Providers:** `lib/features/*/presentation/providers/`
- **Services:** `lib/features/*/data/services/`
- **Repositories:** `lib/features/*/data/repositories/`
- **CacheService:** ONLY Dart data access layer (providers read from here, NEVER direct FFI)

## Event / Callback System
- **Pattern:** Riverpod providers → services → Rust FFI bridge
- **Bridge:** `rust/crates/crispy-ffi/` (dart:ffi)
- **Core logic:** `rust/crates/crispy-core/src/services/`

## Design Tokens
- **Source of truth:** `.ai/crispy_tivi_design_spec.md` + `.ai/docs/project-specs/design_system.md`
- **Dart tokens:** `lib/core/theme/` — CrispySpacing, CrispyRadius, CrispyAnimation
- **Colors:** `Theme.of(context).colorScheme` — never hardcode hex colors
- **Focus ring:** Pure white `#FFFFFF` on every interactive element (D-pad first)

## Routing / Navigation
- **Pattern:** GoRouter or Navigator 2.0
- **Screen index:** Home=0, LiveTV=1, EPG=2, Movies=3, Series=4, Search=5, Library=6, Settings=7

## Test Framework
- **Unit/Widget:** `flutter test` (mocktail for mocks)
- **Integration:** `flutter test integration_test/ -d <device>`
- **Golden/Screenshot:** `flutter test test/golden/`
- **E2E:** Playwright (`e2e/playwright/`)
- **Rust core:** `cargo test -p crispy-core`
- **Coverage:** `flutter test --coverage` + `cargo tarpaulin -p crispy-core`

## Coverage Targets
| Layer | Target |
|-------|--------|
| Rust parsers (M3U, Xtream, Stalker, EPG) | ≥ 90% |
| Rust services/DB | ≥ 90% |
| Rust crypto/security | ≥ 95% |
| Dart domain/application | ≥ 85% |
| Dart widgets | Test behavior, not implementation |

## Widget Composition Rules (replaces Slint markup-only rule)
- **Widgets are pure presentation** — no HTTP calls, no DB queries, no business logic
- **All logic in providers/services** — widgets read from providers only
- **CacheService boundary** — providers access data through CacheService, never direct FFI
- **Composition over inheritance** — prefer small focused widgets composed together
- **GridView.builder / ListView.builder** — ALWAYS use lazy builders for lists > 20 items
- **CachedNetworkImage** — ALWAYS use for remote images (viewport-aware, disk cached)

## D-pad / TV Navigation Rules
- **FocusNode** on every interactive element
- **FocusTraversalGroup** for spatial navigation zones
- **Focus ring visible** via `InputModeScope.showFocusIndicators`
- **Arrow keys:** Up/Down/Left/Right must navigate logically
- **Enter/Select:** activates focused item
- **Escape/Back:** navigates to previous screen or dismisses overlay

## User Journeys (47 total)
See `.ai/planning/USER-JOURNEYS.md` for full specifications.
These are the source of truth for expected behavior.

## Audit Types Available
1. **Callback audit** — verify all provider actions are wired to real implementations
2. **Property audit** — verify all UI-bound state is populated from providers
3. **Navigation audit** — verify all screens reachable, back nav works, no dead ends
4. **Design audit** — verify token usage (no hardcoded colors/spacing/radius)
5. **Journey audit** — trace user journeys through actual code paths
6. **Security audit** — credentials, SQL injection, TLS, crypto
7. **Event audit** — verify all Riverpod state changes produce expected UI updates
