import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/data/dart_algorithm_fallbacks.dart';
import '../../../dvr/domain/utils/dvr_payload.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../profiles/data/profile_service.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/episode_utils.dart';
import '../../domain/utils/vod_utils.dart';
import '../widgets/series_episode_fetcher.dart';
import '../widgets/vod_source_picker.dart';
import 'vod_providers.dart';

/// Single FFI call returning the full episode progress result.
///
/// Both [episodeProgressMapProvider] and [lastWatchedEpisodeIdProvider]
/// derive from this — eliminating a duplicate FFI call when both are
/// watched for the same series.
final _episodeProgressRawProvider = FutureProvider.family.autoDispose<
  ({Map<String, double> progressMap, String? lastWatchedUrl}),
  String
>((ref, seriesId) async {
  final backend = ref.watch(crispyBackendProvider);
  final resultJson = await backend.computeEpisodeProgressFromDb(seriesId);
  return decodeEpisodeProgress(resultJson);
});

/// Episode progress lookup by series ID.
/// Returns `Map<streamUrl, progress>` where
/// progress is 0.0-1.0.
final episodeProgressMapProvider = FutureProvider.family
    .autoDispose<Map<String, double>, String>((ref, seriesId) async {
      final result = await ref.watch(
        _episodeProgressRawProvider(seriesId).future,
      );
      return result.progressMap;
    });

/// Stream URL of the most-recently-watched episode
/// in a series.
final lastWatchedEpisodeIdProvider = FutureProvider.family
    .autoDispose<String?, String>((ref, seriesId) async {
      final result = await ref.watch(
        _episodeProgressRawProvider(seriesId).future,
      );
      return result.lastWatchedUrl;
    });

/// Async backend call for content-rating filtering.
/// Falls back to unfiltered items while the future is pending.
final _filteredVodAsyncProvider = FutureProvider.autoDispose<List<VodItem>>((
  ref,
) async {
  final items = ref.watch(vodProvider.select((s) => s.items));
  final profileState = ref.watch(profileServiceProvider).value;

  if (profileState == null) return items;

  final profile = profileState.activeProfile;

  // No restrictions for unrestricted profiles (or when no profile loaded).
  if (profile == null || !profile.isRestricted) return items;

  final backend = ref.read(crispyBackendProvider);
  final json = jsonEncode(items.map(vodItemToMap).toList());
  final result = await backend.filterVodByContentRating(
    json,
    profile.ratingLevel.value,
  );
  return (jsonDecode(result) as List)
      .cast<Map<String, dynamic>>()
      .map(mapToVodItem)
      .toList();
});

/// Filters VOD items based on active profile's
/// content rating restrictions.
///
/// Uses `.select()` to only rebuild when the items
/// list itself changes, ignoring [VodState] fields
/// like [isLoading] or [selectedCategory].
///
/// Stays synchronous for downstream providers by using
/// [_filteredVodAsyncProvider] internally and falling back
/// to unfiltered items while the async filter is pending.
final filteredVodProvider = Provider.autoDispose<List<VodItem>>((ref) {
  return ref.watch(_filteredVodAsyncProvider).value ??
      ref.watch(vodProvider.select((s) => s.items));
});

/// Filtered movies only.
final filteredMoviesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final items = ref.watch(filteredVodProvider);
  return items.where((i) => i.type == VodType.movie).toList();
});

/// Filtered series only.
final filteredSeriesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final items = ref.watch(filteredVodProvider);
  return items.where((i) => i.type == VodType.series).toList();
});

/// Featured movies for the hero banner (up to 5, movies with a backdrop URL).
///
/// Pre-computes the slice so [VodMoviesTab.build] does no O(n) work.
final featuredMoviesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final movies = ref.watch(filteredMoviesProvider);
  return featuredItems(movies, limit: 5);
});

/// Favorited movies for the Favorites swimlane.
///
/// Pre-computes the filter so [VodMoviesTab.build] does no O(n) work.
final favoriteMoviesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final movies = ref.watch(filteredMoviesProvider);
  return movies.where((m) => m.isFavorite).toList();
});

// ══════════════════════════════════════════════════════════════════
//  Recently Added Providers (Delta Sync Tracking)
// ══════════════════════════════════════════════════════════════════

/// Async backend call for recently-added movies.
final _recentlyAddedMoviesAsyncProvider =
    FutureProvider.autoDispose<List<VodItem>>((ref) async {
      final items = ref.watch(filteredMoviesProvider);
      if (items.isEmpty) return [];
      final backend = ref.read(crispyBackendProvider);
      final json = jsonEncode(items.map(vodItemToMap).toList());
      final result = await backend.filterRecentlyAdded(
        json,
        kRecentlyAddedDays,
        DateTime.now().millisecondsSinceEpoch,
      );
      return (jsonDecode(result) as List)
          .cast<Map<String, dynamic>>()
          .map(mapToVodItem)
          .toList();
    });

/// Movies added in the last [kRecentlyAddedDays] days.
final recentlyAddedMoviesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  return ref.watch(_recentlyAddedMoviesAsyncProvider).value ?? [];
});

/// Async backend call for recently-added series.
final _recentlyAddedSeriesAsyncProvider =
    FutureProvider.autoDispose<List<VodItem>>((ref) async {
      final items = ref.watch(filteredSeriesProvider);
      if (items.isEmpty) return [];
      final backend = ref.read(crispyBackendProvider);
      final json = jsonEncode(items.map(vodItemToMap).toList());
      final result = await backend.filterRecentlyAdded(
        json,
        kRecentlyAddedDays,
        DateTime.now().millisecondsSinceEpoch,
      );
      return (jsonDecode(result) as List)
          .cast<Map<String, dynamic>>()
          .map(mapToVodItem)
          .toList();
    });

/// Series added in the last [kRecentlyAddedDays] days.
final recentlyAddedSeriesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  return ref.watch(_recentlyAddedSeriesAsyncProvider).value ?? [];
});

/// All recently added items (movies + series) sorted by addedAt.
final recentlyAddedAllProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final movies = ref.watch(recentlyAddedMoviesProvider);
  final series = ref.watch(recentlyAddedSeriesProvider);

  final combined = [...movies, ...series];
  combined.sort((a, b) => b.addedAt!.compareTo(a.addedAt!));
  return combined;
});

/// Whether there are any recently added items.
///
/// Uses `.select()` so this provider only rebuilds
/// when the emptiness changes — not when list
/// contents are reordered or items are swapped.
final hasRecentlyAddedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(recentlyAddedAllProvider.select((l) => l.isNotEmpty));
});

/// Whether a VOD item has been marked as watched (progress >= 95%).
///
/// Returns `true` if a [WatchHistoryEntry] exists for the given
/// stream URL and the entry's [WatchHistoryEntry.isNearlyComplete]
/// flag is set (positionMs / durationMs >= [kCompletionThreshold]).
///
/// Keyed by stream URL (same key used by [WatchHistoryService.deriveId]).
final isWatchedProvider = FutureProvider.family.autoDispose<bool, String>((
  ref,
  streamUrl,
) async {
  final service = ref.watch(watchHistoryServiceProvider);
  final id = WatchHistoryService.deriveId(streamUrl);
  final entry = await service.getById(id);
  if (entry == null) return false;
  return entry.isNearlyComplete;
});

// ══════════════════════════════════════════════════════════════════
//  New Episodes Detection (FE-Series-03)
// ══════════════════════════════════════════════════════════════════

/// Number of days a series update is considered "new" for badge display.
const kNewEpisodesDays = 14;

/// Async backend call for series with new episodes.
final _seriesWithNewEpisodesAsyncProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final series = ref.watch(filteredSeriesProvider);
      if (series.isEmpty) return {};
      final backend = ref.read(crispyBackendProvider);
      final seriesJson = jsonEncode(
        series
            .map(
              (s) => {
                'id': s.id,
                'updated_at': s.updatedAt?.millisecondsSinceEpoch,
              },
            )
            .toList(),
      );
      final result = await backend.seriesIdsWithNewEpisodes(
        seriesJson,
        kNewEpisodesDays,
        DateTime.now().millisecondsSinceEpoch,
      );
      return (jsonDecode(result) as List).cast<String>().toSet();
    });

/// Returns the set of series item IDs that have been updated within
/// the last [kNewEpisodesDays] days.
///
/// Heuristic: if [VodItem.updatedAt] is more recent than the cutoff, the
/// series likely has new episodes since the playlist was last synced.
///
/// The set rebuilds only when the series list changes.
final seriesWithNewEpisodesProvider = Provider.autoDispose<Set<String>>((ref) {
  return ref.watch(_seriesWithNewEpisodesAsyncProvider).value ?? {};
});

/// Same-category recommendations for a given VOD item.
///
/// Returns up to 10 movies sharing the same [VodItem.category],
/// excluding the item itself. Uses `.select()` to only rebuild
/// when the movies list changes.
final vodSimilarItemsProvider = Provider.family
    .autoDispose<List<VodItem>, String>((ref, itemId) {
      final movies = ref.watch(vodProvider.select((s) => s.movies));
      final current = movies.where((m) => m.id == itemId).firstOrNull;
      if (current == null || current.category == null) return [];
      return movies
          .where((m) => m.category == current.category && m.id != itemId)
          .take(10)
          .toList();
    });

// ══════════════════════════════════════════════════════════════════
//  Series Episodes Provider
// ══════════════════════════════════════════════════════════════════

/// Key used to identify a series episode fetch request.
///
/// Combines [seriesId] and optional [sourceId] so the provider
/// correctly caches per (series, source) pair.
typedef SeriesEpisodesKey = ({String seriesId, String? sourceId});

/// Fetches and caches episode data for a series.
///
/// autoDispose: kept alive while [SeriesDetailScreen] is mounted
/// and freed when the user pops back — no manual invalidation
/// required, no re-fetch on re-push within the same navigation
/// stack entry.
///
/// Keyed by [SeriesEpisodesKey] so different sources for the
/// same series ID don't share the same cache slot.
final seriesEpisodesProvider = FutureProvider.family
    .autoDispose<EpisodeFetchResult, SeriesEpisodesKey>((ref, key) async {
      return fetchSeriesEpisodes(ref, key.seriesId, sourceId: key.sourceId);
    });

// ══════════════════════════════════════════════════════════════════
//  Unwatched Episode Count (FE-Series-02)
// ══════════════════════════════════════════════════════════════════

/// Returns the count of episodes for a series that have been started
/// but not yet completed (progress > 0 and < [kCompletionThreshold]).
///
/// This gives the user an actionable "episodes to finish" count
/// without requiring a full episode-list API call per series.
/// The count is derived entirely from local watch history.
///
/// Returns 0 when no in-progress episodes exist.
final seriesUnwatchedCountProvider = FutureProvider.family
    .autoDispose<int, String>((ref, seriesId) async {
      final service = ref.watch(watchHistoryServiceProvider);
      final all = await service.getAll();
      return countInProgressEpisodesForSeries(
        all
            .map(
              (e) => (
                seriesId: e.seriesId,
                mediaType: e.mediaType,
                durationMs: e.durationMs,
                isNearlyComplete: e.isNearlyComplete,
              ),
            )
            .toList(),
        seriesId,
      );
    });

// ══════════════════════════════════════════════════════════════════
//  VOD Alternative Sources (FE-VODS-06-ALT)
// ══════════════════════════════════════════════════════════════════

/// Alternative sources for a VOD item (same title from different sources).
///
/// Returns [VodSource] objects for the VodSourcePicker widget.
/// Includes any alternatives beyond the primary item; callers should
/// prepend the item itself as the first source.
/// Returns an empty list when no cross-source duplicates are found.
final vodAlternativeSourcesProvider = FutureProvider.family
    .autoDispose<List<VodSource>, VodItem>((ref, item) async {
      final cache = ref.read(cacheServiceProvider);
      final altMaps = await cache.findVodAlternatives(
        item.name,
        item.year ?? 0,
        item.id,
        10,
      );
      if (altMaps.isEmpty) return [];
      // Resolve source names from settings.
      final settings = ref.read(settingsNotifierProvider).value;
      final sourceMap = <String, String>{};
      if (settings != null) {
        for (final s in settings.sources) {
          sourceMap[s.id] = s.name;
        }
      }
      return altMaps.map((m) {
        final sourceId = m['source_id'] as String?;
        final sourceName = sourceId != null ? sourceMap[sourceId] : null;
        final label =
            sourceName ?? (sourceId != null ? 'Server $sourceId' : 'Default');
        final quality = dartResolveVodQuality(
          m['extension_'] as String?,
          m['stream_url'] as String? ?? '',
        );
        return VodSource(
          label: label,
          streamUrl: m['stream_url'] as String? ?? '',
          quality: quality,
        );
      }).toList();
    });
