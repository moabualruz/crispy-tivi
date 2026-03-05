# Dedup Sweep Report

> Generated: 2026-03-05 | Status: Pending review
> Total groups: 16 | Estimated savings: ~550 lines

---

## Summary

| Group | Priority | Files | Similarity | Est. Savings | Risk |
|-------|----------|-------|------------|--------------|------|
| G1 — Video preview widgets | Highest | 2 | ~98% | ~100 lines | Zero |
| G2 — formatBytes clones | Highest | 6 | ~90% | ~40 lines | Zero |
| G3 — Accent color palette duplication | Highest | 2 | 100% | ~12 lines | Zero |
| G4 — Source-add dialog state+actions | High | 3 dialogs | ~85% | ~45 lines | Low |
| G5 — AsyncValue.when error/loading guard | High | 9+ | ~95% | ~30 lines | Low |
| G6 — Button loading spinner inline | High | 15 | 100% | ~60 lines | Low |
| G7 — Sliver section row (Emby/Jellyfin) | High | 4 | ~90% | ~50 lines | Low |
| G8 — Auto-advance carousel timer | Moderate | 2 | ~80% | ~20 lines | Low |
| G9 — EPG scaffold triplication | Moderate | 1 (3 methods) | 100% | ~10 lines | Zero |
| G10 — Profile screen .when() error widget | Moderate | 3 | ~85% | ~20 lines | Low |
| G11 — padLeft time formatting | Moderate | 6 | ~75% | ~25 lines | Low |
| G12 — extractSortedGroups (Dart vs Rust) | High | 2 | 100% | ~35 lines | Low |
| G13 — top10Vod (Dart vs Rust) | High | 3 | ~85% | ~30 lines | Low |
| G14 — Rating parsing 3-way duplication | Moderate | 4 | ~80% | ~25 lines | Low |
| G15 — JSON parse+fallback in Rust | Moderate | 5 | 100% | ~30 lines | Zero |
| G16 — FFI jsonDecode/cast boilerplate | High | 6 | 100% | ~20 lines | Zero |

---

## GROUP 1 — Video Preview Widgets (EpgVideoPreview / ChannelVideoPreview)

**Priority:** Highest | **Savings:** ~100 lines | **Risk:** Zero

### Files

- `lib/features/epg/presentation/widgets/epg_video_preview.dart` — EPG timeline video preview (109 lines)
- `lib/features/iptv/presentation/widgets/channel_video_preview.dart` — Channel list TV video preview (109 lines)

### Shared Pattern

Line-for-line identical: same `GlobalKey`, `_reportRect()`, `LayoutBuilder` constraint tracking, `AspectRatio(16/9)`, idle/buffering overlay, `playerModeProvider` integration. Only difference: class name and one comment word.

```dart
void _reportRect() {
  final box = _key.currentContext?.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    final scale = UiAutoScale.of(context!);
    final position = box.localToGlobal(Offset.zero) / scale;
    ref.read(playerModeProvider.notifier).updatePreviewRect(
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
    );
  }
}
```

### Differences

- `epg_video_preview.dart` → comment says "EPG layout"
- `channel_video_preview.dart` → comment says "channel list TV layout"

### Merge Approach

Delete one file. Create a single `VideoPreviewWidget` in `lib/core/widgets/` parameterized by an optional label. Both callers import the shared widget.

### Status: [ ] Pending

---

## GROUP 2 — formatBytes Clones (6 independent implementations)

**Priority:** Highest | **Savings:** ~40 lines | **Risk:** Zero

### Files

- `lib/core/utils/format_utils.dart` — canonical `formatBytes()` (12 lines)
- `lib/features/dvr/presentation/widgets/file_metadata_sheet.dart` — `_formatSize()` (11 lines)
- `lib/features/dvr/presentation/screens/cloud_file_grid.dart` — inline `kBytesPerMb` + arithmetic
- `lib/features/dvr/domain/entities/recording.dart` — inline `(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB`
- `lib/features/dvr/data/dvr_state.dart` — inline `(totalStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB`
- `lib/features/settings/presentation/widgets/network_diagnostics_settings.dart` — inline `(bytes / 1024 / 1024).toStringAsFixed(2)} MB`
- `lib/features/dvr/domain/utils/storage_breakdown.dart` — `mb` getter using `bytes / (1024 * 1024)`

### Shared Pattern

```dart
// 5 independent byte→human-readable conversions, all doing 1024-division
String _formatSize(int bytes) {
  if (bytes >= _kBytesPerGb) return '${(bytes / _kBytesPerGb).toStringAsFixed(2)} GB';
  if (bytes >= _kBytesPerMb) return '${(bytes / _kBytesPerMb).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
```

### Differences

- Decimal precision varies: 0, 1, or 2 places
- GB handling: only canonical and `_formatSize` handle GB
- Edge case: only `_formatSize` handles `0 B`

### Merge Approach

Redirect all 5 clones to `formatBytes()` from `format_utils.dart`. Optionally move `formatBytes` to Rust for consistency (Rust already has `formatBytes` for GB-level — see audit sprint 10).

### Status: [ ] Pending

---

## GROUP 3 — Accent Color Palette Duplication

**Priority:** Highest | **Savings:** ~12 lines | **Risk:** Zero

### Files

- `lib/core/theme/accent_color.dart` — `AccentColorValues.color` switch (5 hex values)
- `lib/features/profiles/presentation/profile_constants.dart` — `kProfileAccentColors` list (same 5 hex values + extras)

### Shared Pattern

```dart
// Both files define:
Color(0xFF3B82F6), // Blue
Color(0xFF00BFA5), // Teal
Color(0xFFFF6D00), // Orange
Color(0xFFAA00FF), // Purple
Color(0xFF00C853), // Green
```

### Differences

- `accent_color.dart` → switch statement on enum
- `profile_constants.dart` → const List

### Merge Approach

Extract a shared `const List<Color> kAppAccentPalette` from `AccentColorValues`, reference it from `kProfileAccentColors`.

### Status: [ ] Pending

---

## GROUP 4 — Source-Add Dialog State Machine

**Priority:** High | **Savings:** ~45 lines | **Risk:** Low

### Files

- `lib/features/settings/presentation/widgets/source_add_dialogs.dart` — `_M3uAddDialogState` + `_XtreamAddDialogState`
- `lib/features/settings/presentation/widgets/source_portal_dialogs.dart` — `_StalkerAddDialogState`

### Shared Pattern

All three dialogs share identical `bool _isVerifying / String? _error` state machine, identical `actions:` block (~15 lines), identical loading spinner in the submit button.

```dart
actions: [
  TextButton(
    onPressed: _isVerifying ? null : () => Navigator.pop(context),
    child: const Text('Cancel'),
  ),
  FilledButton(
    onPressed: _isVerifying ? null : _submit,
    child: _isVerifying
      ? const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Text('Add'),
  ),
],
```

### Differences

- Number and names of `TextEditingController`s
- Verification logic in `_submit()`

### Merge Approach

Extract `SourceDialogActions` widget or a `VerifyingDialogMixin` that provides the actions row, `_isVerifying`, and `_error` state.

### Status: [ ] Pending

---

## GROUP 5 — AsyncValue.when Error/Loading Guard

**Priority:** High | **Savings:** ~30 lines | **Risk:** Low

### Files

9+ screens using the exact pattern: `profile_management_screen.dart`, `profile_watch_history_screen.dart`, `media_server_home_screen.dart`, `settings_panel.dart`, `recording_search_delegate.dart`, `transfer_list.dart`, `plex_home_screen.dart`, `paginated_library_screen.dart`, and others.

### Shared Pattern

```dart
someAsync.when(
  loading: () => const LoadingStateWidget(),
  error: (e, _) => Center(child: Text('Error: $e')),
  data: (value) => _buildBody(...),
);
```

### Differences

- Some use `colorScheme.error` styling, others use unstyled `Text`
- Error text prefix varies ("Error: ", "Error loading profiles: ", etc.)

### Merge Approach

Create `ErrorStateWidget(Object error)` matching `LoadingStateWidget` pattern. Both are already consistent loading/error guards.

### Status: [ ] Pending

---

## GROUP 6 — Button Loading Spinner Inline

**Priority:** High | **Savings:** ~60 lines | **Risk:** Low

### Files

15 files: `source_add_dialogs.dart` (2×), `source_portal_dialogs.dart`, `onboarding_form_step.dart`, `media_server_login_screen.dart`, `pin_input_dialog.dart` (2×), `network_diagnostics_settings.dart` (2×), `cloud_storage_settings.dart`, `source_access_dialog.dart`, and 4 more.

### Shared Pattern

```dart
child: _isLoading
  ? const SizedBox(width: 20, height: 20,
      child: CircularProgressIndicator(strokeWidth: 2))
  : const Text('Submit'),
```

### Merge Approach

Create `AsyncFilledButton({bool isLoading, String label, VoidCallback? onPressed})` widget in `lib/core/widgets/`.

### Status: [ ] Pending

---

## GROUP 7 — Sliver Section Row (Emby/Jellyfin Home)

**Priority:** High | **Savings:** ~50 lines | **Risk:** Low

### Files

- `lib/features/media_servers/emby/presentation/screens/emby_home_screen.dart` — 3 blocks
- `lib/features/media_servers/jellyfin/presentation/screens/jellyfin_home_screen.dart` — 3 blocks
- `lib/features/vod/presentation/screens/series_browser_screen.dart` — 1 block
- `lib/features/vod/presentation/widgets/vod_movies_tab.dart` — 1 block

### Shared Pattern

```dart
...sectionAsync.when(
  data: (items) {
    if (items.isEmpty) return const <Widget>[];
    return [SliverToBoxAdapter(child: HorizontalScrollRow<T>(...))];
  },
  loading: () => const <Widget>[],
  error: (_, _) => const <Widget>[],
),
```

### Merge Approach

Create `asyncSliverSection<T>(AsyncValue<List<T>>, {...params})` helper that returns `List<Widget>`.

### Status: [ ] Pending

---

## GROUP 8 — Auto-Advance Carousel Timer

**Priority:** Moderate | **Savings:** ~20 lines | **Risk:** Low

### Files

- `lib/features/vod/presentation/widgets/vod_featured_hero.dart` — `_cycleTimer`
- `lib/features/media_servers/plex/presentation/screens/plex_home_screen.dart` — `_PlexHeroBanner._timer`

### Shared Pattern

Same `Timer.periodic`, same `mounted` check, same `(index + 1) % length`, same dispose pattern.

### Merge Approach

Extract an `AutoAdvanceMixin` or make `VodFeaturedHero` generic enough for Plex.

### Status: [ ] Pending

---

## GROUP 9 — EPG Scaffold Triplication

**Priority:** Moderate | **Savings:** ~10 lines | **Risk:** Zero

### Files

- `lib/features/epg/presentation/screens/epg_timeline_screen.dart` — `_buildLoading()`, `_buildError()`, `_buildEmpty()` all wrap the same `Scaffold(appBar: AppBar(title: const Text('Program Guide')))`

### Merge Approach

Extract `_buildScaffold({required Widget body})` private method.

### Status: [ ] Pending

---

## GROUP 10 — Profile Screen .when() Error Widget

**Priority:** Moderate | **Savings:** ~20 lines | **Risk:** Low

### Files

- `lib/features/profiles/presentation/screens/profile_management_screen.dart`
- `lib/features/profiles/presentation/screens/profile_selection_screen.dart`
- `lib/features/profiles/presentation/screens/profile_watch_history_screen.dart`

### Merge Approach

Use the `ErrorStateWidget` from G5.

### Status: [ ] Pending

---

## GROUP 11 — padLeft Time Formatting

**Priority:** Moderate | **Savings:** ~25 lines | **Risk:** Low

### Files

6 files: `sync_conflict_dialog.dart`, `recording_search_delegate.dart`, `time_header_painter.dart`, `epg_reminder_sheet.dart`, `plex_library_screen.dart`, `pin_input_dialog.dart`

### Shared Pattern

`int.toString().padLeft(2, '0')` repeated for hours, minutes, days.

### Merge Approach

Redirect to existing `formatHHmm` / `formatDMY` from `date_format_utils.dart`.

### Status: [ ] Pending

---

## GROUP 12 — extractSortedGroups (Dart Pure vs Rust FFI)

**Priority:** High | **Savings:** ~35 lines | **Risk:** Low

### Files

- `lib/features/iptv/domain/utils/channel_utils.dart` — Dart `extractSortedGroups()` (37 lines)
- `rust/crates/crispy-core/src/algorithms/categories.rs` — Rust `extract_sorted_groups()` (canonical)

### Shared Pattern

Both implement Arabic-first, Latin-second alphabetical sort. Functionally identical.

### Merge Approach

Delete Dart version. Redirect callers (`channel_providers.dart`, `playlist_sync_helpers.dart`) to use `backend.extractSortedGroups()` FFI call.

### Status: [ ] Pending

---

## GROUP 13 — top10Vod (Dart vs Rust filter_top_vod)

**Priority:** High | **Savings:** ~30 lines | **Risk:** Low

### Files

- `lib/features/vod/domain/utils/vod_utils.dart` — Dart `top10Vod()` (30 lines)
- `rust/crates/crispy-core/src/algorithms/vod_sorting/filter.rs` — Rust `filter_top_vod()`
- `lib/features/home/presentation/providers/home_providers.dart` — calls Dart version

### Differences

- Dart requires HTTP-prefixed poster URL; Rust accepts any non-empty poster/backdrop
- Dart uses `double.tryParse`; Rust uses `parse_rating`

### Merge Approach

Align Rust `filter_top_vod` to match the poster-URL filter. Redirect `top10VodProvider` to use FFI call. Delete Dart version.

### Status: [ ] Pending

---

## GROUP 14 — Rating Parsing 3-Way Duplication

**Priority:** Moderate | **Savings:** ~25 lines | **Risk:** Low

### Files

- `lib/features/vod/domain/utils/vod_utils.dart` — `double.tryParse(rating) ?? 0`
- `lib/core/data/memory_backend_algo_vod.dart` — `double.tryParse(rating) ?? 0` (3 sites)
- `lib/core/data/memory_backend_reco_sections.dart` — `double.tryParse(rating) ?? double.nan` (3 sites)
- `rust/crates/crispy-core/src/algorithms/vod_sorting/mod.rs` — `parse_rating()` → `f64::NEG_INFINITY`

### Merge Approach

Consolidate Dart sites to use a shared `parseRating(String?)` function with consistent NaN/sentinel. MemoryBackend mirrors keep the Dart version.

### Status: [ ] Pending

---

## GROUP 15 — JSON Parse+Fallback in Rust

**Priority:** Moderate | **Savings:** ~30 lines | **Risk:** Zero

### Files

5 Rust modules: `vod_sorting/sorting.rs`, `vod_sorting/filter.rs`, `watch_progress.rs`, `source_filter.rs`, `dvr.rs`

### Shared Pattern

```rust
let items: Vec<T> = match serde_json::from_str(json) {
    Ok(v) => v,
    Err(_) => return "[]".to_string(),
};
```

Repeated 9+ times with identical fallback.

### Merge Approach

Extract `fn parse_json_vec<T: DeserializeOwned>(json: &str) -> Option<Vec<T>>` in a shared util module. Note: `vod_sorting/mod.rs` already has `parse_vod_array` in test code — promote to non-test.

### Status: [ ] Pending

---

## GROUP 16 — FFI jsonDecode/cast Boilerplate

**Priority:** High | **Savings:** ~20 lines | **Risk:** Zero

### Files

6 `ffi_backend_*.dart` files: channels, vod, dvr, profiles, epg, settings

### Shared Pattern

```dart
final json = await rust_api.loadXxx();
return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
```

13 occurrences of `(jsonDecode(json) as List).cast<Map<String, dynamic>>()`.

### Merge Approach

Extract `List<Map<String, dynamic>> _decodeJsonList(String json)` helper in a shared FFI util.

### Status: [ ] Pending

---
