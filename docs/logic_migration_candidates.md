# Business Logic Migration Candidates — Dart → Rust

> Generated: 2026-03-05 | Status: Pending review
> Candidates: HIGH: 10, MEDIUM-HIGH: 8, MEDIUM: 5 | Quick wins: ~8

---

## Summary

| Tier | Count | Est. Lines Removable | Avg Complexity |
|------|-------|---------------------|----------------|
| HIGH | 10 | ~520 lines | Simple-Medium |
| MEDIUM-HIGH | 8 | ~180 lines | Simple |
| MEDIUM | 5 | ~100 lines | Trivial-Simple |
| Deferred/Skip | 7 | — | — |

Quick wins (HIGH + Trivial/Simple): **8 candidates, ~350 lines**

---

## HIGH Priority — Pure Logic, Move to Rust

### 1. filterAndSortChannels

- **File:** `lib/features/iptv/presentation/providers/channel_list_state.dart` (lines 17–134)
- **What:** Multi-pass channel filter (hidden groups, hidden IDs, duplicates, group, search) + multi-mode sort (manual, name, date, watchtime, default). 118 lines.
- **Complexity:** Medium (5 filter passes, 5 sort modes)
- **Dependency Class:** A — Pure (no Flutter imports in function body)
- **Callers:** Every channel state mutation via `ChannelListState.copyWith()`
- **Target layer:** `rust/crates/crispy-core/src/algorithms/sorting.rs` (extend existing module)
- **Migration approach:** New `filter_and_sort_channels(channels_json, params_json, now_ms) → String` function. Rust already has `sort_channels` and `filter_channels_by_source` — combine and extend.
- **Existing tests:** 42 Dart unit tests in `channel_list_state_test.dart`
- **Status:** [ ] Pending

---

### 2. resolveNextEpisodes

- **File:** `lib/features/vod/domain/utils/episode_utils.dart` (lines 56–121)
- **What:** For each series watch-history entry ≥90% complete, finds the next sequential episode by season/episode number and substitutes it. 65 lines.
- **Complexity:** Medium (multi-field sort + index search across VOD items)
- **Dependency Class:** A — Pure
- **Callers:** `continueWatchingSeriesNextEpisodeProvider` in `home_providers.dart`
- **Target layer:** `rust/crates/crispy-core/src/algorithms/watch_history.rs` or new `episode_resolution.rs`
- **Migration approach:** New `resolve_next_episodes(history_json, vod_items_json, threshold) → String`. Could leverage SQL join for efficiency.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

### 3. computeStorageBreakdown

- **File:** `lib/features/dvr/domain/utils/storage_breakdown.dart` (lines 85–154)
- **What:** Groups recordings by status, sums bytes per category and per channel, identifies 30-day cleanup candidates. 70 lines + 80 lines of model classes.
- **Complexity:** Simple-Medium (multi-pass aggregation with date logic)
- **Dependency Class:** A — Pure
- **Callers:** `storageBreakdownProvider` in DVR feature
- **Target layer:** `rust/crates/crispy-core/src/algorithms/dvr.rs` (extend existing)
- **Migration approach:** New `compute_storage_breakdown(recordings_json, now_ms) → String` returning JSON with categories, channelBytes, cleanUpCandidates.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

### 4. computeWatchStreak + ProfileViewingStats.compute

- **File:** `lib/features/profiles/domain/utils/watch_streak.dart` (40 lines) + `lib/features/profiles/domain/utils/profile_stats.dart` (97 lines)
- **What:** Watch streak counts consecutive calendar days with at least one watch. Profile stats aggregates total hours, top channels, top genres. 137 lines combined.
- **Complexity:** Simple (day-bucketing + backwards walk + aggregation)
- **Dependency Class:** A — Pure
- **Callers:** Profile stats widgets, profile detail screens
- **Target layer:** `rust/crates/crispy-core/src/algorithms/watch_history.rs`
- **Migration approach:** New `compute_watch_streak(timestamps_json, now_ms) → u32` and `compute_profile_stats(history_json) → String`. Natural pair — stats depends on streak.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

### 5. filterUpcomingPrograms

- **File:** `lib/features/home/domain/utils/upcoming_programs.dart` (lines 23–46)
- **What:** Filters EPG entries across favorite channels, keeps programs starting within 120-min window, sorts by start time, caps at 20. 23 lines.
- **Complexity:** Simple
- **Dependency Class:** A — Pure
- **Callers:** `upcomingProgramsProvider` in `home_providers.dart`
- **Target layer:** `rust/crates/crispy-core/src/algorithms/epg_matching.rs`
- **Migration approach:** New `filter_upcoming_programs(epg_json, favorite_ids_json, now_ms, window_minutes, limit) → String`.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

### 6. channelIdsWithMatchingLiveProgram + mergeEpgMatchedChannels

- **File:** `lib/features/iptv/domain/utils/epg_search.dart` (61 lines)
- **What:** Returns channel IDs where the currently-airing program title contains a search query. Merges EPG-matched channels into a base list without duplicates. Paired functions.
- **Complexity:** Simple
- **Dependency Class:** A — Pure
- **Callers:** Channel search providers
- **Target layer:** `rust/crates/crispy-core/src/algorithms/search.rs` (extend)
- **Migration approach:** New `search_channels_by_live_program(epg_json, query, now_ms) → String` returning matched channel IDs.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

### 7. mergeDedupSort + filterByCwStatus

- **File:** `lib/features/favorites/domain/utils/cw_filter_utils.dart` (68 lines)
- **What:** Merges two watch-history lists, deduplicates by id, sorts by lastWatched desc. Filters by all/watching/completed status.
- **Complexity:** Simple
- **Dependency Class:** A — Pure
- **Callers:** `continueWatchingProvider` and favorites screens
- **Target layer:** `rust/crates/crispy-core/src/algorithms/watch_history.rs`
- **Migration approach:** Extend existing `filter_continue_watching` or add `merge_dedup_sort_history(a_json, b_json, filter) → String`.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

### 8. Completion threshold unification (0.90 vs 0.95 bug)

- **File:** Multiple: `playback_progress_provider.dart` (0.95), `favorites_history_service.dart` (0.90), `favorites_up_next.dart` (0.95 hardcoded), `episode_utils.dart` (0.90)
- **What:** Three different completion thresholds used inconsistently. Rust has `COMPLETION_THRESHOLD = 0.95` in `watch_progress.rs`. Dart has `kCompletionThreshold = 0.95` in `constants.dart`, but `WatchPosition.isCompleted = progress > 0.9` and `kNextEpisodeThreshold = 0.90` diverge.
- **Complexity:** Trivial (constant alignment)
- **Dependency Class:** A — Pure constants
- **Callers:** 5+ providers and entity methods
- **Target layer:** Rust `watch_progress.rs` — expose constants via FFI sync functions
- **Migration approach:** Export `COMPLETION_THRESHOLD` and `NEXT_EPISODE_THRESHOLD` from Rust. Dart reads them via `backend.completionThreshold()`. Fix all callers.
- **Existing tests:** Threshold tests exist in Rust; Dart tests use 0.95 in some places
- **Status:** [ ] Pending

---

### 9. seriesIdsWithNewEpisodes + countInProgressEpisodesForSeries

- **File:** `lib/features/dvr/domain/utils/dvr_payload.dart` (71 lines)
- **What:** Returns series IDs with `updatedAt` within last 14 days. Counts in-progress episodes for a series. Paired functions.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Callers:** `seriesWithNewEpisodesProvider` in `vod_providers.dart`
- **Target layer:** `rust/crates/crispy-core/src/algorithms/watch_history.rs`
- **Migration approach:** New `series_ids_with_new_episodes(series_json, days, now_ms) → String` and `count_in_progress_episodes(history_json, series_id) → usize`.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

### 10. filterRecentlyAdded + top10Vod + resolveVodQuality

- **File:** `lib/features/vod/domain/utils/vod_utils.dart` (105 lines)
- **What:** `filterRecentlyAdded` — 7-day cutoff filter. `top10Vod` — rating-based top items with poster filter. `resolveVodQuality` — quality keyword detection from stream URL/extension. Three pure functions.
- **Complexity:** Simple
- **Dependency Class:** A — Pure
- **Callers:** Home screen providers, VOD detail screens
- **Target layer:** `rust/crates/crispy-core/src/algorithms/vod_sorting/` (extend filter.rs)
- **Migration approach:** `filter_recently_added(items_json, cutoff_days, now_ms) → String`, enhance existing `filter_top_vod`, new `resolve_vod_quality(extension, stream_url) → Option<String>`.
- **Existing tests:** No dedicated unit tests
- **Status:** [ ] Pending

---

## MEDIUM-HIGH Priority — Extractable with Minor Refactor

### 11. sortFavorites

- **File:** `lib/features/favorites/domain/utils/favorites_sort_utils.dart` (33 lines)
- **What:** Sorts favorite channels by recently-added, name A-Z, name Z-A, or content-type.
- **Complexity:** Simple
- **Dependency Class:** A — Pure
- **Callers:** Favorites screen providers
- **Migration approach:** New `sort_favorites(channels_json, sort_mode) → String` in `algorithms/sorting.rs`.
- **Status:** [ ] Pending

---

### 12. matchesFilter + sortFiles (DVR cloud browser)

- **File:** `lib/features/dvr/domain/utils/file_filter.dart` (121 lines)
- **What:** Classifies files by extension (video/audio/subtitle/other), sorts remote file listings by name/date/size with directories first.
- **Complexity:** Simple-Medium
- **Dependency Class:** A — Pure
- **Migration approach:** New `classify_file_type(filename) → String` and `sort_remote_files(files_json, order) → String` in `algorithms/dvr.rs`.
- **Status:** [ ] Pending

---

### 13. filterRecordings

- **File:** `lib/features/dvr/domain/utils/recording_search.dart` (19 lines)
- **What:** Case-insensitive search across recording program name, channel name, and start date.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Migration approach:** New `filter_recordings(recordings_json, query) → String` in `algorithms/search.rs`.
- **Status:** [ ] Pending

---

### 14. buildSearchCategories

- **File:** `lib/features/search/domain/utils/search_categories.dart` (25 lines)
- **What:** Merges VOD categories + channel groups into a sorted deduplicated list.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Migration approach:** New `build_search_categories(vod_categories_json, channel_groups_json) → String` in `algorithms/categories.rs`.
- **Status:** [ ] Pending

---

### 15. VodState._buildCategoryMap + _buildTypeCategories

- **File:** `lib/features/vod/presentation/providers/vod_providers.dart` (lines 68–87)
- **What:** Groups VOD items by category, extracts sorted category lists by type. Rust already has `build_vod_category_map`.
- **Complexity:** Simple
- **Dependency Class:** B — Parametric (static methods on state class)
- **Migration approach:** Redirect to existing Rust `build_vod_category_map` FFI call. Add `build_type_categories` to Rust.
- **Status:** [ ] Pending

---

### 16. EpgState.getUpcomingPrograms + getNowPlaying

- **File:** `lib/features/epg/presentation/providers/epg_providers.dart` (lines 158–176)
- **What:** Returns next N programmes after the live one for a channel, sorted by startTime.
- **Complexity:** Simple
- **Dependency Class:** B — Parametric (method on state class)
- **Migration approach:** New `get_upcoming_epg_for_channel(entries_json, now_ms, count) → String` in `algorithms/epg_matching.rs`.
- **Status:** [ ] Pending

---

### 17. sortCategoriesWithFavorites

- **File:** `lib/features/vod/presentation/providers/favorite_categories_provider.dart` (lines 59–66)
- **What:** Splits categories into favourited/non-favourited, sorts each alphabetically, concatenates.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Migration approach:** New `sort_categories_with_favorites(categories_json, favorites_json) → String`.
- **Status:** [ ] Pending

---

### 18. vodSimilarItemsProvider (same-category recommendation)

- **File:** `lib/features/vod/presentation/providers/vod_providers.dart` (lines 383–392)
- **What:** Returns up to 10 movies sharing the same category, excluding the current item.
- **Complexity:** Simple
- **Dependency Class:** B — Parametric (Provider.family)
- **Migration approach:** New `similar_vod_items(items_json, item_id, limit) → String` in `algorithms/vod_sorting/`.
- **Status:** [ ] Pending

---

## MEDIUM Priority — Mixed Logic/Orchestration

### 19. dynamicSectionLabel

- **File:** `lib/features/home/domain/utils/home_utils.dart` (40 lines)
- **What:** Computes home-screen section header labels with item counts and badges.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Migration approach:** Could move count logic to Rust; string formatting stays in Dart (localization concern).
- **Status:** [ ] Pending

---

### 20. EPG date utilities (getEpgWeekStart, isSameDay, epgTodayLabel)

- **File:** `lib/features/epg/domain/utils/epg_date_utils.dart` (39 lines)
- **What:** Date arithmetic — Monday of a week, same-day comparison, abbreviated month+day label.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Migration approach:** New functions in `algorithms/timezone.rs`. Low priority — display formatters.
- **Status:** [ ] Pending

---

### 21. isLockActive + lockRemaining (PIN lockout)

- **File:** `lib/features/settings/domain/utils/pin_lockout.dart` (20 lines)
- **What:** Compares timestamps to determine if PIN lockout is active and remaining duration.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Migration approach:** New `is_lock_active(locked_until_ms, now_ms) → bool` in `algorithms/pin.rs`.
- **Status:** [ ] Pending

---

### 22. _badgeKind — VOD new-release/new-to-library classification

- **File:** `lib/features/vod/presentation/widgets/recently_added_section.dart` (lines 24–38)
- **What:** Classifies VOD item as "new release" (year >= now.year - 1) or "new to library" (added within 30 days).
- **Complexity:** Trivial
- **Dependency Class:** B — Inside widget build()
- **Migration approach:** New `vod_badge_kind(year, added_at_ms, now_ms) → String` in `algorithms/vod_sorting/`.
- **Status:** [ ] Pending

---

### 23. episodeCountBySeason

- **File:** `lib/features/vod/domain/utils/episode_utils.dart` (lines 127–135)
- **What:** Builds season number → episode count map. 8 lines.
- **Complexity:** Trivial
- **Dependency Class:** A — Pure
- **Migration approach:** New `episode_count_by_season(episodes_json) → String` in `algorithms/vod_sorting/`.
- **Status:** [ ] Pending

---

## LOW Priority — Must Stay in Presentation Layer

| # | File | What | Why Stay |
|---|------|------|----------|
| 1 | `lib/core/utils/group_icon_helper.dart` | `getGroupIcon()` | Returns `IconData` (Flutter type); wrapper already delegates to Rust |
| 2 | `lib/features/vod/presentation/mixins/vod_sortable_browser_mixin.dart` | `VodSortableBrowserMixin` | Flutter `ConsumerState` mixin, `TextEditingController`, `setState()` |
| 3 | `lib/features/iptv/presentation/widgets/channel_list_helpers.dart` | `channelStateSliver()` | Returns `Widget?` |
| 4 | `lib/features/media_servers/shared/utils/error_sanitizer.dart` | `sanitizeError()` | Depends on `DioException` (I/O boundary) |
| 5 | `lib/core/domain/entities/playlist_source_type_ext.dart` | `PlaylistSourceTypeUi` | Returns `IconData` |
| 6 | `lib/core/domain/mixins/playback_progress_mixin.dart` | `isInProgress` | Single boolean expression — trivial, no migration value |
| 7 | `lib/features/player/presentation/providers/osd_providers.dart` | `freezeTimer` elapsed calc | OSD auto-hide is UI concern, not business logic |

---
