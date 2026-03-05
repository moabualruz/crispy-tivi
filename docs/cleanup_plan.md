# Cleanup & Optimization Plan — Sweep Results

Generated: 2026-03-05
Sources: `/sweep-dedup` (4 agents), `/sweep-logic` (3 agents)

## Overview

| Sprint | Scope | Risk | Tasks | Est. Lines Saved | Status |
|--------|-------|------|-------|------------------|--------|
| 1 | Zero-risk redirects (use existing utils/tokens) | Zero | 10 | ~120 | Done |
| 2 | New shared components + token additions | Low | 9 | ~100 | Done |
| 3 | Pure function extractions from presentation | Low | 10 | ~200 | Done |
| 4 | Shared widget extractions + schema fixes | Medium | 7 | ~180 | Done |
| 5 | State-coupled logic extractions | Medium | 5 | ~60 | Done |
| 6 | Doc sync | Zero | 1 | 0 | Done |
| **Total** | | | **42** | **~660** | **All Done** |

---

## Sprint 1 — Zero-Risk Redirects

**Risk:** Zero — all changes redirect to existing canonical implementations.
No new code, no behavior change.

| # | Task | Files | Source (dedup/logic) |
|---|------|-------|---------------------|
| 1.1 | Replace `_formatDuration(int)` in 2 VOD widgets → `DurationFormatter.humanShort(Duration(minutes: m))` | `vod_landscape_card.dart`, `quick_info_card.dart` | Dedup-B #1, Logic-C #1 |
| 1.2 | Replace `_timeRemaining()` in OSD → `'${DurationFormatter.humanShort(remaining)} left'` | `osd_mini_guide.dart` | Dedup-B #2, Logic-C #4 |
| 1.3 | Replace inline `positionMs/durationMs` → `entry.progress` at 8 call sites | `continue_watching_section.dart`, `cross_device_section.dart`, `episode_playback_helper.dart`, `watch_history_service.dart` (×2), `start_media_server_playback_use_case.dart`, `vod_details_screen.dart`, `home_providers.dart` | Logic-A #15, Logic-C #6 |
| 1.4 | Replace `_formatDate` YYYY-MM-DD → `formatYMD(dt)` from `date_format_utils.dart` | `recording_search_delegate.dart` | Dedup-B #11, Logic-C #5c |
| 1.5 | Replace inline `padLeft(2,'0')` HH:mm → `formatHHmm`/`formatHHmmLocal` | `epg_program_block.dart`, `sync_status_indicator.dart` (also fixes hours zero-pad bug), `epg_reminder_sheet.dart` | Dedup-B #2, Logic-C #5a/b/d |
| 1.6 | Replace `_formatDate` relative → `formatRelativeTime` | `profile_watch_history_screen.dart` | Dedup-B #3, Logic-A #14 |
| 1.7 | Use existing `CrispyColors.vignetteStart/End` in plex_home_screen, `CrispyColors.netflixRed` in profile_constants, `AccentColor.blue.color` in theme_provider | `plex_home_screen.dart`, `profile_constants.dart`, `theme_provider.dart` | Dedup-D #1B/1D/1E |
| 1.8 | Use `OsdIconButton` or extract `osdButtonStyle()` in 5 player overlay files | `audio_equalizer_overlay.dart`, `bookmark_overlay.dart`, `player_queue_overlay.dart`, `osd_ab_loop_button.dart`, `osd_center_controls.dart` | Dedup-D #6 |
| 1.9 | Use `CrispyAnimation.normal` for `Duration(ms:300)` (2 files), `CrispyAnimation.osdAutoHide` for `Duration(seconds:4)` (2 files) | `channel_tv_layout.dart`, `channel_list_screen.dart`, `home_sections.dart`, `media_server_browser_screen.dart` | Dedup-D #5C/5F |
| 1.10 | Replace `'iptv_vod'`/`'iptv_epg'` literals → `SearchContentSource` constants | `enhanced_search_result_card.dart`, `search_repository_impl.dart` | Dedup-D #4A |

**Gate:** `flutter test && flutter analyze && cd rust && cargo clippy --workspace -- -D warnings`

**Agent Dispatch:**
- Tasks {1.1, 1.2}: 1 agent (VOD + player widgets, no overlap)
- Tasks {1.3}: 1 agent (8 files, all `entry.progress` replacements)
- Tasks {1.4, 1.5, 1.6}: 1 agent (date formatting across features)
- Tasks {1.7, 1.9}: 1 agent (token/constant replacements)
- Tasks {1.8}: 1 agent (OSD button style consolidation)
- Task {1.10}: 1 agent (search constants)
- Total: 6 agents, background-safe, all parallel (no file overlap)

---

## Sprint 2 — New Shared Components & Token Additions

**Risk:** Low — new shared component + caller updates. Tests exist for callers.

| # | Task | Files | Source |
|---|------|-------|-------|
| 2.1 | Add `LoadingStateWidget` to `lib/core/widgets/`, replace 26 `Center(child: CircularProgressIndicator())` sites | `lib/core/widgets/loading_state_widget.dart` (new) + 20 feature files | Dedup-A #7 |
| 2.2 | Replace 6 bare `error: (e, _) => Center(child: Text('Error: $e'))` → `ErrorStateWidget` | 6 feature files | Dedup-A #8 |
| 2.3 | Add `CrispyColors.statusGood/statusWarn/statusError` tokens; replace hardcoded hex in 3 files | `crispy_colors.dart`, `vod_source_picker.dart`, `add_profile_dialog.dart`, `settings_shared_widgets.dart` | Dedup-D #1A |
| 2.4 | Add `CrispyColors.highlightAmber` token; replace `Colors.amber` in 4 files | `crispy_colors.dart`, `osd_bottom_bar.dart`, `osd_ab_loop_button.dart`, `category_dropdown.dart`, `favorite_star_overlay.dart` | Dedup-D #1F |
| 2.5 | Add `CrispyAnimation.snackBarDuration` (2s), `.toastDuration` (3s), `.heroAdvanceInterval` (8s); replace inline durations | `crispy_animation.dart` (or equivalent token file) + 15+ feature files | Dedup-D #5A/5B/5D |
| 2.6 | Add `dartIsHashedPin` + `dartSanitizeFilename` + `dartGuessLogoDomains` to `dart_algorithm_fallbacks.dart`; redirect 6 callers | `dart_algorithm_fallbacks.dart`, `ws_backend_algorithms.dart`, `memory_backend_sync.dart`, `ws_backend_dvr.dart`, `memory_backend_algo_core.dart`, `ws_backend_settings.dart` | Dedup-B #6/7/12 |
| 2.7 | Extract `MediaTypeIconHelper.iconFor(MediaType)` → `lib/core/utils/`; redirect 4 call sites | New `media_type_icons.dart` + `enhanced_search_result_card.dart`, `grouped_results_list.dart`, `profile_watch_history_screen.dart`, `emby_my_media_section.dart` | Dedup-D #7 |
| 2.8 | Replace manual `Timer` debounce → `Debouncer` utility in 3 files | `channel_list_screen.dart`, `channel_tv_layout.dart`, `search_providers.dart` | Logic-C #10 |
| 2.9 | Replace `EdgeInsets.all(4)` → `CrispySpacing.xs` (2 files), `vertical: 2` → `CrispySpacing.xxs` (1 file) | `generated_placeholder.dart`, `continue_watching_section.dart`, `settings_shared_widgets.dart` | Dedup-D #2A/2C |

**Gate:** `flutter test && flutter analyze`

**Agent Dispatch:**
- Tasks {2.1, 2.2}: 1 agent (loading/error widget extraction — touches many files but single concern)
- Tasks {2.3, 2.4, 2.5, 2.9}: 1 agent (all token additions to `crispy_colors.dart`/`crispy_animation.dart` + replacements)
- Task {2.6}: 1 agent (backend fallback consolidation, 6 data-layer files)
- Tasks {2.7, 2.8}: 1 agent (utility extractions)
- Total: 4 agents, background-safe, all parallel

---

## Sprint 3 — Pure Function Extractions from Presentation

**Risk:** Low — extracting pure functions from presentation to domain/utils.
Functions have zero framework dependencies. Tests should be added for each.

| # | Task | From → To | Lines | Source |
|---|------|-----------|-------|-------|
| 3.1 | Extract `_sorted(channels, FavoritesSort)` | `favorites_recently_watched.dart` → `favorites/domain/utils/favorites_sort.dart` | 22 | Logic-A #4 |
| 3.2 | Extract `dynamicSectionLabel` | `home_sections.dart` → `home/domain/utils/home_utils.dart` | 25 | Logic-A #5 |
| 3.3 | Extract `resolveNextEpisodes` | `home_providers.dart` → `vod/domain/utils/episode_utils.dart` | 65 | Logic-A #6 |
| 3.4 | Extract `ProfileViewingStats.compute` + `_mediaTypeToGenreLabel` | `profile_viewing_stats_tile.dart` → `profiles/domain/utils/profile_stats.dart` | 65 | Logic-A #7 |
| 3.5 | Extract `_filter` recording search | `recording_search_delegate.dart` → `dvr/domain/utils/recording_search.dart` | 18 | Logic-A #8 |
| 3.6 | Extract `_episodeCountBySeason` + `_upNextIndex` | `series_episodes_tab.dart` → `vod/domain/utils/episode_utils.dart` | 16 | Logic-A #9/10 |
| 3.7 | Extract `_segmentLabel` | `skip_segment_button.dart` → `player/domain/utils/skip_segment_utils.dart` | 8 | Logic-A #12 |
| 3.8 | Extract `_embyAuthHeader` + `_toServerType` | `media_server_providers.dart` → `media_servers/shared/utils/` | 9 | Logic-A #11 |
| 3.9 | Add `_ratingLabel` as `displayLabel` getter on `ContentRatingLevel` | `add_profile_dialog.dart` → `parental/domain/content_rating.dart` | 4 | Logic-A #13 |
| 3.10 | Add `formatTimeRemaining(Duration)` to `date_format_utils.dart`; redirect `favorites_continue_watching.dart` + `osd_mini_guide.dart` | 2 files → `date_format_utils.dart` | 9 | Logic-A #2 |

**Gate:** `flutter test && flutter analyze`

**Agent Dispatch:**
- Tasks {3.1, 3.5}: 1 agent (favorites + DVR domain utils — no overlap)
- Tasks {3.2, 3.3, 3.6}: 1 agent (home/VOD episode utils — `episode_utils.dart` shared)
- Tasks {3.4, 3.9}: 1 agent (profiles domain — no overlap)
- Tasks {3.7, 3.8, 3.10}: 1 agent (player + media_servers + core utils — no overlap)
- Total: 4 agents, background-safe, all parallel

---

## Sprint 4 — Shared Widget Extractions & Schema Fixes

**Risk:** Medium — new shared widgets, behavioral parameterization required.

| # | Task | Files | Source |
|---|------|-------|-------|
| 4.1 | Merge `_PlexNotConnected` + `_NotConnectedState` → shared `NotConnectedWidget` | `plex_home_screen.dart`, `media_server_home_screen.dart`, new `not_connected_widget.dart` | Dedup-A #1 |
| 4.2 | Extract `ContinueWatchingMerger` (merge+dedup+sort CW providers) — used by `ContinueWatchingTab`, `UpNextTab`, `HomeContinueWatchingSection` | `favorites_continue_watching.dart`, `favorites_up_next.dart`, `home_sections.dart` → shared util | Dedup-A #3, Logic-B #3.2 |
| 4.3 | Unify `_buildList` responsive ListView/GridView from favorites tabs | `favorites_continue_watching.dart`, `favorites_recently_watched.dart` → shared `FavoritesList` widget | Dedup-A #4 |
| 4.4 | Unify `VodMoviesGrid`/`SeriesMoviesGrid` SliverGrid scaffolding → parameterized `MediaGrid` | `vod_movies_grid.dart`, `series_movies_grid.dart` | Dedup-A #5 |
| 4.5 | Extract `VodBrowserShell` for loading/error/empty guard triad | `vod_browser_screen.dart`, `series_browser_screen.dart` | Dedup-A #2 |
| 4.6 | Consolidate `recordingToMap` divergence — unify datetime format (`_toNaiveDateTime` everywhere) | `cache_service_dvr.dart`, `dvr_state.dart` | Dedup-C #1 |
| 4.7 | Fix `sync_status_indicator.dart` hours zero-padding bug (use `formatHHmmLocal`) | `sync_status_indicator.dart` | Logic-C #5b (bug) |

**Gate:** `flutter test && flutter analyze && cd rust && cargo test`

**Agent Dispatch:**
- Tasks {4.1}: 1 agent (media server widget merge)
- Tasks {4.2, 4.3}: 1 agent (favorites shared utils + widget — same files)
- Tasks {4.4, 4.5}: 1 agent (VOD grid + browser shell — related)
- Tasks {4.6}: 1 agent (DVR schema fix — data layer)
- Task {4.7}: Trivial — include in Sprint 1 instead if convenient
- Total: 4 agents, background-safe

---

## Sprint 5 — State-Coupled Logic Extractions

**Risk:** Medium — logic tightly bound to Riverpod state; partial extraction.

| # | Task | Files | Source |
|---|------|-------|-------|
| 5.1 | Extract `filterByContentRating(items, ratingLevel)` from `filteredVodProvider` → `vod/domain/utils/vod_utils.dart` | `vod_providers.dart` | Logic-B #2.4 |
| 5.2 | Extract `filterEpgChannels` from `EpgState.filteredChannels` → pure function | `epg_providers.dart` | Logic-B #3.5 |
| 5.3 | Extract `EpgReminder` class to `iptv/domain/entities/` with clock-injectable `isDue(now)` | `epg_reminder_sheet.dart` → `iptv/domain/entities/epg_reminder.dart` | Logic-B #1.2 |
| 5.4 | Unify `_kTrailerDelay` — `vod_hero_banner.dart` (3s) vs `vod_featured_hero.dart` (2s) — pick one or make configurable | `vod_hero_banner.dart`, `vod_featured_hero.dart` | Dedup-D #5E |
| 5.5 | Extract `decodeEpisodeProgressMap(String json) → Map<String,double>` from `episodeProgressMapProvider` | `vod_providers.dart` | Logic-B #6.2 |

**Gate:** `flutter test && flutter analyze`

**Agent Dispatch:**
- Tasks {5.1, 5.2, 5.5}: 1 agent (VOD + EPG provider extractions — shared `vod_providers.dart`)
- Tasks {5.3}: 1 agent (EPG reminder domain extraction)
- Task {5.4}: 1 agent (VOD hero constants)
- Total: 3 agents, background-safe

---

## Sprint 6 — Doc Sync

| # | Task |
|---|------|
| 6.1 | Update all tracking docs: `PROGRESS.md`, `TASKS.md`, `EXECUTION_STATE.md`, `GLOBAL_PROGRESS.md`, `.ai/docs/` as needed |

---

## Decision Log

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Zero-risk redirects first (Sprint 1) | Unlocks cleaner codebase for subsequent extractions; no behavioral change possible |
| D2 | `DurationFormatter.humanShort` preferred over Rust `formatDurationMinutes` for widget-level formatting | Avoids async bridge overhead; Dart util already exists and matches widget expectations (omits trailing "0m") |
| D3 | `_formatSize` stays in Sprint 1 only if `formatBytes` handles zero/negative; otherwise Sprint 4 with behavioral fix | Behavioral difference in edge cases |
| D4 | `ContentRatingLevel.fromString` in Dart NOT deleted (parallel to Rust intentionally) | Dart domain type serves UI/profile management; Rust handles bulk backend filtering |
| D5 | `_defaultChannelSort` in Dart NOT deleted (richer client-side sort pipeline) | Rust `sort_channels` lacks multi-sort mode support (byWatchTime, manual order, etc.) |
| D6 | `copyWith` boilerplate NOT addressed (340 lines across 11 entities) | Structural cost of non-generated Dart; would require `freezed` adoption which is out of scope |
| D7 | `@JsonSerializable` media server models NOT addressed | Already code-generated; no manual duplication |
| D8 | SavedStream/KeywordRule camelCase JSON keys NOT changed | Low risk of breakage vs. minimal benefit; note inconsistency for future migration |
| D9 | `formatPlaybackDuration(posMs, posMs)` pattern in thumbnail/OSD kept as-is | Likely intentional for compact timestamp display; not a clear bug |

## Stay-in-Place Exclusions

| # | File | What | Why Stay |
|---|------|------|----------|
| E1 | `channel_list_state.dart` | `_defaultChannelSort` | Client-side multi-sort pipeline; Rust lacks these modes |
| E2 | `content_rating.dart` | `ContentRatingLevel.fromString` | Intentional dual representation (Dart domain type + Rust i32) |
| E3 | `vod_providers.dart` | `VodState._buildCategoryMap` | Builds per-category item map that Rust doesn't provide |
| E4 | All `@JsonSerializable` models | Generated fromJson/toJson | Code-generated, not manual duplication |
| E5 | `cache_service_*.dart` | 10+ `_mapTo*`/`*ToMap` pairs | Necessary serialization layer; uniform boilerplate, not extractable |
| E6 | All `copyWith` methods | Domain entity boilerplate (340 lines) | Requires `freezed` adoption (out of scope) |
| E7 | `normalizeServerUrl` in `url_utils.dart` | Different from `normalizeApiBaseUrl` (keeps path vs strips) | Distinct operations, not true duplicates |

## Progress Summary

| Sprint | Planned | Done | Blocked | Notes |
|--------|---------|------|---------|-------|
| 1 | 10 | 10 | 0 | 1849 tests, gate pass |
| 2 | 9 | 9 | 0 | 1849 tests, gate pass |
| 3 | 10 | 10 | 0 | 1937 tests (+88), gate pass |
| 4 | 7 | 7 | 0 | 1947 tests (+10), gate pass |
| 5 | 5 | 5 | 0 | 1982 tests (+35), gate pass |
| 6 | 1 | 1 | 0 | Doc sync complete |
