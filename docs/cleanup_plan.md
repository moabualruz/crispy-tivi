# Cleanup & Rust Migration Plan

> Created: 2026-03-05 | Last Updated: 2026-03-05
> Source reports: `docs/dedup_report.md`, `docs/logic_migration_candidates.md`
> Total items: 39 across 8 sprints (6 work + 1 Rust internal + 1 final)

---

## Overview

| Sprint | Scope | Items | Risk | Status |
|--------|-------|-------|------|--------|
| 1 | Zero-risk dedup (deletes + redirects) | 6 | None | [ ] Pending |
| 2 | Shared Dart widgets + helpers | 5 | Low | [ ] Pending |
| 3 | Rust: threshold constants + JSON helpers | 5 | Low | [ ] Pending |
| 4 | Rust migration: channel + VOD algorithms | 5 | Medium | [ ] Pending |
| 5 | Rust migration: watch history + profiles | 5 | Medium | [ ] Pending |
| 6 | Rust migration: EPG + DVR + search | 5 | Medium | [ ] Pending |
| 7 | Rust migration: complex algorithms | 4 | Higher | [ ] Pending |
| Final | Cleanup & validation | 7 | None | [ ] Pending |

---

## Sprint 1 — Zero-Risk Dedup (Deletes & Redirects)

**Goal:** Eliminate byte-identical or near-identical duplicates. No behavior change.

**Gate:** `cd rust && cargo test` + `cd rust && cargo clippy --workspace -- -D warnings` + `dart analyze lib/ test/` + `flutter test`

**Agent Dispatch:**
- Tasks {1.1, 1.2, 1.3}: 1 agent (overlapping theme/constant files)
- Tasks {1.4, 1.5}: 1 agent (overlapping FFI files)
- Task {1.6}: 1 agent (independent)
- Total: 3 agents, parallel

| # | Task | Source | Files | Savings | Status |
|---|------|--------|-------|---------|--------|
| 1.1 | Merge `EpgVideoPreview` + `ChannelVideoPreview` → shared widget | Dedup G1 | `epg_video_preview.dart`, `channel_video_preview.dart`, `core/widgets/` | ~100 lines | [ ] |
| 1.2 | Redirect `formatBytes` clones to `format_utils.dart` | Dedup G2 | `file_metadata_sheet.dart`, `cloud_file_grid.dart`, `recording.dart`, `dvr_state.dart`, `network_diagnostics_settings.dart`, `storage_breakdown.dart` | ~40 lines | [ ] |
| 1.3 | Unify accent color palette (`kProfileAccentColors` → `AccentColorValues`) | Dedup G3 | `accent_color.dart`, `profile_constants.dart` | ~12 lines | [ ] |
| 1.4 | Extract `_decodeJsonList` / `_decodeMap` helper for FFI backend | Dedup G16 | `ffi_backend_*.dart` (6 files) | ~20 lines | [ ] |
| 1.5 | Extract `_countFromResult` helper for WsBackend | Dedup G16 | `ws_backend_*.dart` (5 files) | ~10 lines | [ ] |
| 1.6 | Delete Dart `extractSortedGroups`, redirect to FFI | Dedup G12 | `channel_utils.dart`, `channel_providers.dart`, `playlist_sync_helpers.dart` | ~35 lines | [ ] |

**Sprint 1 total: ~217 lines** | Commit: (pending)

---

## Sprint 2 — Shared Dart Widgets & Helpers

**Goal:** Extract shared UI components to eliminate copy-paste patterns.

**Gate:** `dart analyze lib/ test/` + `flutter test`

**Agent Dispatch:**
- Tasks {2.1, 2.2}: 1 agent (widget extractions)
- Tasks {2.3, 2.4}: 1 agent (dialog/section patterns)
- Task {2.5}: 1 agent (independent)
- Total: 3 agents, parallel

| # | Task | Source | Files | Savings | Status |
|---|------|--------|-------|---------|--------|
| 2.1 | Create `ErrorStateWidget` to unify `.when()` error arms | Dedup G5, G10 | 9+ screens, `core/widgets/` | ~30 lines | [ ] |
| 2.2 | Create `AsyncFilledButton` to replace 15 inline spinners | Dedup G6 | 15 files, `core/widgets/` | ~60 lines | [ ] |
| 2.3 | Extract `SourceDialogActions` from 3 source-add dialogs | Dedup G4 | `source_add_dialogs.dart`, `source_portal_dialogs.dart` | ~45 lines | [ ] |
| 2.4 | Extract `asyncSliverSection` helper for Emby/Jellyfin/VOD | Dedup G7 | 4 files | ~50 lines | [ ] |
| 2.5 | Redirect `padLeft` time formatting to `date_format_utils.dart` | Dedup G11 | 6 files | ~25 lines | [ ] |

**Sprint 2 total: ~210 lines** | Commit: (pending)

---

## Sprint 3 — Rust Internal: Constants + JSON Helpers

**Goal:** Clean up Rust internals — extract shared helpers, name constants, unify thresholds.

**Gate:** `cd rust && cargo test` + `cd rust && cargo clippy --workspace -- -D warnings` + `flutter test`

**Agent Dispatch:**
- Tasks {3.1, 3.2, 3.3}: 1 agent (Rust algorithms)
- Tasks {3.4, 3.5}: 1 agent (Rust + Dart threshold alignment)
- Total: 2 agents, parallel

| # | Task | Source | Files | Savings | Status |
|---|------|--------|-------|---------|--------|
| 3.1 | Extract `parse_json_vec<T>` helper from 9 algorithm functions | Dedup G15 | `vod_sorting/*.rs`, `watch_progress.rs`, `source_filter.rs`, `dvr.rs` | ~30 lines | [ ] |
| 3.2 | Replace raw `0.95` in `recommendations/mod.rs` tests with `COMPLETION_THRESHOLD` | Logic #8 | `recommendations/mod.rs`, `watch_progress.rs` | ~5 lines | [ ] |
| 3.3 | Add `NEXT_EPISODE_THRESHOLD` constant, name table string constants | Logic #8 | `watch_progress.rs`, `recommendations/sections.rs`, `database/mod.rs`, services | ~10 lines | [ ] |
| 3.4 | Expose Rust thresholds via FFI sync functions | Logic #8 | `crispy-ffi/src/api/algorithms.rs`, `crispy_backend.dart` | +20 lines (new FFI) | [ ] |
| 3.5 | Fix Dart threshold inconsistency (0.90 vs 0.95) — align all callers | Logic #8 | `favorites_history_service.dart`, `favorites_up_next.dart`, `episode_utils.dart`, `constants.dart` | ~10 lines | [ ] |

**Sprint 3 total: ~75 lines saved + threshold bug fix** | Commit: (pending)

---

## Sprint 4 — Rust Migration: Channel + VOD Algorithms

**Goal:** Move channel filter/sort pipeline and VOD utilities to Rust.

**Gate:** `cd rust && cargo test` + `cd rust && cargo clippy --workspace -- -D warnings` + `dart analyze lib/ test/` + `flutter test`

**Agent Dispatch:**
- Task {4.1}: 1 agent (largest — Rust + Dart, sequential)
- Tasks {4.2, 4.3}: 1 agent (overlapping vod_sorting module)
- Tasks {4.4, 4.5}: 1 agent (overlapping FFI + backend)
- Total: 3 agents, first sequential, then 2 parallel

| # | Task | Source | Files | Savings | Status |
|---|------|--------|-------|---------|--------|
| 4.1 | Migrate `filterAndSortChannels` to Rust `algorithms/sorting.rs` | Logic #1 | `sorting.rs` + FFI + `channel_list_state.dart` | ~118 lines | [ ] |
| 4.2 | Migrate `filterRecentlyAdded` to Rust `vod_sorting/filter.rs` | Logic #10 | `filter.rs` + FFI + `vod_utils.dart` + providers | ~20 lines | [ ] |
| 4.3 | Align `top10Vod` with Rust `filter_top_vod`, redirect callers | Dedup G13 + Logic #10 | `filter.rs` + `vod_utils.dart` + `home_providers.dart` | ~30 lines | [ ] |
| 4.4 | Migrate `sortFavorites` to Rust | Logic #11 | `sorting.rs` + FFI + `favorites_sort_utils.dart` | ~33 lines | [ ] |
| 4.5 | Migrate `sortCategoriesWithFavorites` + `_buildTypeCategories` | Logic #15, #17 | `categories.rs` + FFI + providers | ~25 lines | [ ] |

**Sprint 4 total: ~226 lines** | Commit: (pending)

---

## Sprint 5 — Rust Migration: Watch History + Profiles

**Goal:** Move watch-history algorithms and profile statistics to Rust.

**Gate:** `cd rust && cargo test` + `cd rust && cargo clippy --workspace -- -D warnings` + `flutter test`

**Agent Dispatch:**
- Tasks {5.1, 5.2}: 1 agent (watch_history.rs module)
- Tasks {5.3, 5.4}: 1 agent (overlapping FFI + backend files)
- Task {5.5}: 1 agent (independent)
- Total: 3 agents, parallel

| # | Task | Source | Files | Savings | Status |
|---|------|--------|-------|---------|--------|
| 5.1 | Migrate `computeWatchStreak` to Rust `watch_history.rs` | Logic #4 | `watch_history.rs` + FFI + `watch_streak.dart` | ~40 lines | [ ] |
| 5.2 | Migrate `ProfileViewingStats.compute` to Rust | Logic #4 | `watch_history.rs` + FFI + `profile_stats.dart` | ~97 lines | [ ] |
| 5.3 | Migrate `mergeDedupSort` + `filterByCwStatus` to Rust | Logic #7 | `watch_history.rs` + FFI + `cw_filter_utils.dart` | ~68 lines | [ ] |
| 5.4 | Migrate `seriesIdsWithNewEpisodes` + `countInProgressEpisodes` | Logic #9 | `watch_history.rs` or `dvr.rs` + FFI + `dvr_payload.dart` | ~71 lines | [ ] |
| 5.5 | Consolidate `parseRating` in Dart (shared helper for MemoryBackend) | Dedup G14 | `vod_utils.dart`, `memory_backend_algo_vod.dart`, `memory_backend_reco_*.dart` | ~25 lines | [ ] |

**Sprint 5 total: ~301 lines** | Commit: (pending)

---

## Sprint 6 — Rust Migration: EPG + DVR + Search

**Goal:** Move EPG, DVR, and search algorithms to Rust.

**Gate:** `cd rust && cargo test` + `cd rust && cargo clippy --workspace -- -D warnings` + `flutter test`

**Agent Dispatch:**
- Tasks {6.1, 6.2}: 1 agent (epg_matching.rs module)
- Tasks {6.3, 6.4}: 1 agent (dvr.rs + search.rs)
- Task {6.5}: 1 agent (independent)
- Total: 3 agents, parallel

| # | Task | Source | Files | Savings | Status |
|---|------|--------|-------|---------|--------|
| 6.1 | Migrate `filterUpcomingPrograms` to Rust `epg_matching.rs` | Logic #5 | `epg_matching.rs` + FFI + `upcoming_programs.dart` | ~23 lines | [ ] |
| 6.2 | Migrate `channelIdsWithMatchingLiveProgram` to Rust `search.rs` | Logic #6 | `search.rs` + FFI + `epg_search.dart` | ~61 lines | [ ] |
| 6.3 | Migrate `computeStorageBreakdown` to Rust `dvr.rs` | Logic #3 | `dvr.rs` + FFI + `storage_breakdown.dart` | ~70 lines | [ ] |
| 6.4 | Migrate `filterRecordings` + `matchesFilter`/`sortFiles` | Logic #12, #13 | `dvr.rs` + `search.rs` + FFI + `file_filter.dart` + `recording_search.dart` | ~140 lines | [ ] |
| 6.5 | Migrate `buildSearchCategories` to Rust `categories.rs` | Logic #14 | `categories.rs` + FFI + `search_categories.dart` | ~25 lines | [ ] |

**Sprint 6 total: ~319 lines** | Commit: (pending)

---

## Sprint 7 — Rust Migration: Complex Algorithms

**Goal:** Move the most complex remaining algorithms to Rust.

**Gate:** `cd rust && cargo test` + `cd rust && cargo clippy --workspace -- -D warnings` + `flutter test`

**Agent Dispatch:**
- Task {7.1}: 1 agent (complex, sequential)
- Tasks {7.2, 7.3}: 1 agent (parallel, simpler)
- Task {7.4}: 1 agent (independent)
- Total: 3 agents (7.1 first, then {7.2, 7.3, 7.4} parallel)

| # | Task | Source | Files | Savings | Status |
|---|------|--------|-------|---------|--------|
| 7.1 | Migrate `resolveNextEpisodes` to Rust | Logic #2 | New module or `watch_history.rs` + FFI + `episode_utils.dart` | ~65 lines | [ ] |
| 7.2 | Migrate `vodSimilarItems` (same-category reco) to Rust | Logic #18 | `vod_sorting/` + FFI + `vod_providers.dart` | ~8 lines | [ ] |
| 7.3 | Migrate `episodeCountBySeason` + `_badgeKind` | Logic #22, #23 | `vod_sorting/` + FFI + `episode_utils.dart` + widget | ~22 lines | [ ] |
| 7.4 | Migrate `isLockActive`/`lockRemaining` to Rust `pin.rs` | Logic #21 | `pin.rs` + FFI + `pin_lockout.dart` | ~20 lines | [ ] |

**Sprint 7 total: ~115 lines** | Commit: (pending)

---

## Final Sprint — Cleanup & Validation

**Goal:** Confirm zero issues, update all docs, write memory notes.

| # | Task | Status |
|---|------|--------|
| F.1 | Run full Rust test suite — confirm all pass | [ ] |
| F.2 | Run `flutter test` — confirm all pass | [ ] |
| F.3 | Run `dart analyze lib/ test/` — confirm 0 issues | [ ] |
| F.4 | Run formatters (`cargo fmt`, `dart format`) | [ ] |
| F.5 | Update dedup report — mark completed groups | [ ] |
| F.6 | Update logic report — mark completed candidates | [ ] |
| F.7 | Update project memory | [ ] |

---

## Progress Summary

| Sprint | Scope | Lines Saved | Items Done | Status |
|--------|-------|------------|------------|--------|
| 1 | Zero-risk dedup | ~217 | 0/6 | [ ] |
| 2 | Shared widgets | ~210 | 0/5 | [ ] |
| 3 | Rust constants | ~75 | 0/5 | [ ] |
| 4 | Channel+VOD→Rust | ~226 | 0/5 | [ ] |
| 5 | History+Profile→Rust | ~301 | 0/5 | [ ] |
| 6 | EPG+DVR+Search→Rust | ~319 | 0/5 | [ ] |
| 7 | Complex→Rust | ~115 | 0/4 | [ ] |
| **Total** | | **~1,463** | **0/35** | |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-05 | Dedup before logic migration | Zero-risk wins unblock cleaner extractions |
| 2026-03-05 | Rust internals Sprint 3 before migrations Sprint 4+ | JSON helper and constants are prerequisites |
| 2026-03-05 | Threshold unification early (Sprint 3) | Fixes a real bug (0.90 vs 0.95 inconsistency) |
| 2026-03-05 | filterAndSortChannels first Rust migration | Highest impact: 118 lines, runs on every state mutation |
| 2026-03-05 | resolveNextEpisodes last (Sprint 7) | Most complex, needs careful SQL join design |
| 2026-03-05 | MemoryBackend fallbacks stay in Dart | Intentional design — Dart mirrors for WsBackend/test sync paths |

---

## References

- [Dedup Report](docs/dedup_report.md)
- [Logic Migration Candidates](docs/logic_migration_candidates.md)
