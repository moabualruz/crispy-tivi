import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/vod_repository_impl.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../profiles/data/profile_service.dart';
import '../../data/episode_progress_codec.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/vod_utils.dart';
import 'vod_providers.dart';

export 'vod_series_providers.dart';

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

  final repo = ref.read(vodRepositoryProvider);
  return repo.filterVodByContentRating(items, profile.ratingLevel.value);
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
      final repo = ref.read(vodRepositoryProvider);
      return repo.filterRecentlyAdded(
        items,
        kRecentlyAddedDays,
        DateTime.now().millisecondsSinceEpoch,
      );
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
      final repo = ref.read(vodRepositoryProvider);
      return repo.filterRecentlyAdded(
        items,
        kRecentlyAddedDays,
        DateTime.now().millisecondsSinceEpoch,
      );
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
