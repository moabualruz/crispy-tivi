# E2E Issue Tracker

Issues found during E2E testing are logged here.
Each entry includes the date, affected screen, description,
screenshot reference, and resolution status.

| Date | Screen | Issue | Screenshot | Status |
|------|--------|-------|------------|--------|

## Resolved Issues

### 2026-02-20: Stale build cache references old package name

- **Screen**: Web build
- **Description**: `flutter build web --release` failed with
  `Error: Not found: 'package:crispy_tivi/main.dart'` --
  stale `.dart_tool/flutter_build/` cache from before rename.
- **Fix**: `flutter clean && flutter pub get && flutter build web --release`
- **Status**: RESOLVED

### 2026-02-20: Playwright networkidle timeout

- **Screen**: All Playwright tests
- **Description**: `waitForLoadState('networkidle')` never resolved
  because Flutter web (CanvasKit) continuously fetches font/WASM
  resources.
- **Fix**: Changed to `waitForLoadState('domcontentloaded')` +
  `waitForSelector('canvas')` to detect Flutter first-frame render.
- **Status**: RESOLVED

### 2026-02-20: Flutter accessibility button outside viewport

- **Screen**: Playwright "Enable accessibility" button
- **Description**: `accessBtn.click()` failed because Flutter
  positions the semantics placeholder button offscreen.
- **Fix**: Use `click({ force: true })` to bypass viewport check.
- **Status**: RESOLVED

### 2026-02-20: Golden test -- profile selection missing DB override

- **Screen**: ProfileSelectionScreen golden test
- **Description**: `MissingPluginException` for path_provider because
  `appDatabaseProvider` was not overridden. Even with
  `profileServiceProvider` overridden, other providers in the widget
  tree still triggered the default DB initialization.
- **Fix**: Added `appDatabaseProvider`, `cacheServiceProvider`, and
  `configServiceProvider` overrides to profile selection golden test.
- **Status**: RESOLVED

### 2026-02-20: Golden test -- SettingsScreen needs GoRouter

- **Screen**: SettingsScreen golden test
- **Description**: `GoError: There is no GoRouterState above the
  current context` -- SettingsScreen uses `GoRouterState.of(context)`
  in initState for auto-open dialog feature.
- **Fix**: Wrapped SettingsScreen in GoRouter with
  `MaterialApp.router(routerConfig: router)`.
- **Status**: RESOLVED

### 2026-02-20: Windows integration tests fail in batch mode

- **Screen**: All integration flow tests
- **Description**: `flutter test integration_test/ -d windows` fails
  for flow tests after app_test.dart. Error: "Unable to start the
  app on the device" / "The log reader stopped unexpectedly."
  Each test file launches a separate app instance, and sequential
  Windows desktop launches conflict.
- **Workaround**: Run each flow test individually -- all pass.
  `flutter test integration_test/flows/profile_flow_test.dart -d windows`
- **Status**: KNOWN LIMITATION (Flutter Windows integration test runner)

### 2026-02-20: EPG golden test is time-sensitive

- **Screen**: EpgTimelineScreen golden test
- **Description**: 0.19% pixel diff when running after delay because
  the EPG screen uses `DateTime.now()` for the "now" time indicator.
- **Workaround**: Regenerate baselines with `--update-goldens`
  before running regression checks.
- **Status**: KNOWN LIMITATION (time-dependent UI)

### 2026-02-21: Null check crash during keyboard Tab navigation (BUG-001)

- **Screen**: Home screen / any screen with focus traversal
- **Description**: Pressing Tab key 15+ times triggers
  `Null check operator used on a null value` at main.dart.js:35340,
  followed by 5 PAGE_ERRORs: `Cannot read properties of null
  (reading 'toString')`. Likely in FocusWrapper or focus traversal
  policy. Reproducible on every keyboard-driven session.
- **Console trace**: See `e2e/reports/manual-crawl-logs.txt` line 74-88
- **Fix**: Added `mounted` guard + `addPostFrameCallback` in
  `focus_wrapper.dart` to defer scroll and check widget is still alive.
- **Status**: FIXED

### 2026-02-21: Sub-pages remove global navigation sidebar (BUG-002)

- **Screen**: Media Servers, Connect Jellyfin, and other Settings
  sub-routes
- **Description**: Navigating to any Settings sub-page (e.g.,
  "Browse Media Servers") hides the nav rail entirely. Only a back
  arrow remains. Users cannot access other tabs without going back.
  Keyboard/remote users are trapped.
- **Screenshots**: `e2e/reports/screenshots/manual-crawl/012-*.png`
  through `032-*.png` (all stuck on Media Servers)
- **Fix**: Moved 15 sub-page routes inside `ShellRoute` in
  `app_router.dart` so `AppShell` (nav rail) stays in widget tree.
- **Status**: FIXED

### 2026-02-21: First-run routes to Settings + auto-opens Xtream dialog (BUG-003)

- **Screen**: After profile selection (first run, no sources)
- **Description**: After selecting Default profile with no sources
  configured, app navigates to Settings instead of Home and
  auto-opens the "Add Xtream Codes" dialog unprompted.
- **Screenshots**: `e2e/reports/screenshots/manual-crawl/003-*.png`
- **Fix**: Changed `profile_selection_screen.dart` to navigate to
  Home (not Settings) when no sources configured. The Home screen's
  empty state now prompts users to add a source.
- **Status**: FIXED

### 2026-02-21: Escape key does not navigate back from sub-pages (BUG-004)

- **Screen**: All Settings sub-pages
- **Description**: Pressing Escape on sub-pages does nothing. D-pad
  "Back" button equivalent doesn't work.
- **Fix**: Fixed by BUG-002 fix — `AppShell` with its Escape key
  `CallbackShortcuts` now stays in the widget tree on sub-pages.
- **Status**: FIXED

### 2026-02-21: Input fields use placeholder-only labels (BUG-005)

- **Screen**: Add Xtream Codes dialog, Add M3U dialog, all source forms
- **Description**: Form fields use hintText placeholders only, no
  persistent floating labels. Placeholder disappears when focused.
- **Fix**: Investigation showed all forms already use `labelText`
  (floating labels). The CanvasKit rendering in screenshots made them
  look like hint-only placeholders. Not a real bug.
- **Status**: NOT A BUG (false positive from screenshot rendering)

### 2026-02-21: Quick Access cards link to unimplemented features (BUG-006)

- **Screen**: Home > Quick Access
- **Description**: "Multi View", "DVR", "Cloud Storage" cards shown
  but features not implemented. Clicking leads to empty/error screens.
- **Fix**: Added "Beta" badge to Multi View, DVR, and Cloud Storage
  Quick Access tiles. Features are implemented but need configuration;
  badge sets user expectations. Tiles remain functional.
- **Status**: FIXED

### 2026-02-21: Profile card icons are generic placeholders (BUG-008)

- **Screen**: Profile Selection
- **Description**: Default profile uses generic purple person icon.
  Add Profile uses basic `+` in dark box. Doesn't match premium UI.
- **Fix**: Upgraded profile avatars with gradient backgrounds,
  rounded corners (`CrispyRadius.md`), and improved "Add Profile"
  tile with `person_add_outlined` icon. Applied same style to
  profile management screen and avatar chooser dialog.
- **Status**: FIXED

### 2026-02-21: Empty state inconsistency across screens (BUG-009)

- **Screen**: Live TV, Program Guide, Home
- **Description**: Empty states vary: Live TV has text only, Guide
  has "Refresh" button (wrong action when no sources), Home shows
  Quick Access but no "add source" prompt.
- **Fix**: Created shared `EmptyStateWidget` in
  `lib/core/widgets/empty_state_widget.dart`. Updated all 4 screens
  (Live TV, EPG, VOD Movies, Series) to use consistent empty states
  with icon + title + description + "Go to Settings" button.
- **Status**: FIXED

## Notes

### cupertino_icons font warning

`flutter build web` reports:
> Expected to find fonts for (MaterialIcons,
> packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons).

This is a warning only -- cupertino_icons are referenced in pubspec
but not used in any screen. Can be removed from pubspec if desired.
