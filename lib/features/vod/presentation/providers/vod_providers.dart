import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/providers/source_filter_provider.dart';
import '../../../dvr/domain/utils/dvr_payload.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../profiles/data/profile_service.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/episode_utils.dart';
import '../../domain/utils/vod_filter_utils.dart';
import '../../domain/utils/vod_utils.dart';
import '../widgets/series_episode_fetcher.dart';
import '../widgets/vod_source_picker.dart';
import 'vod_favorites_provider.dart';

/// VOD browsing state.
///
/// Computed collections ([movies], [series], [byCategory], etc.)
/// are pre-computed once at construction time so that repeated
/// reads are O(1) instead of O(n).
class VodState {
  VodState({
    this.items = const [],
    this.categories = const [],
    this.selectedCategory,
    this.isLoading = false,
    this.error,
  }) : movies = items.where((i) => i.type == VodType.movie).toList(),
       series = items.where((i) => i.type == VodType.series).toList(),
       featured = featuredItems(items),
       newReleases = newReleasesItems(items),
       filtered =
           selectedCategory == null
               ? items
               : items.where((i) => i.category == selectedCategory).toList(),
       byCategory = _buildCategoryMap(items),
       movieCategories = _buildTypeCategories(items, VodType.movie),
       seriesCategories = _buildTypeCategories(items, VodType.series);

  final List<VodItem> items;
  final List<String> categories;
  final String? selectedCategory;
  final bool isLoading;
  final String? error;

  /// Items grouped by category (pre-computed).
  final Map<String, List<VodItem>> byCategory;

  /// Items filtered by selected category (pre-computed).
  final List<VodItem> filtered;

  /// Featured items for hero banner (pre-computed).
  final List<VodItem> featured;

  /// New releases sorted by year (pre-computed).
  final List<VodItem> newReleases;

  /// Movie items only (pre-computed).
  final List<VodItem> movies;

  /// Series items only (pre-computed).
  final List<VodItem> series;

  /// Movie-specific categories (pre-computed).
  final List<String> movieCategories;

  /// Series-specific categories (pre-computed).
  final List<String> seriesCategories;

  static Map<String, List<VodItem>> _buildCategoryMap(List<VodItem> items) {
    final map = <String, List<VodItem>>{};
    for (final item in items) {
      final cat = item.category ?? 'Uncategorized';
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  static List<String> _buildTypeCategories(List<VodItem> items, VodType type) {
    final cats = <String>{};
    for (final item in items) {
      if (item.type == type &&
          item.category != null &&
          item.category!.isNotEmpty) {
        cats.add(item.category!);
      }
    }
    return cats.toList()..sort();
  }

  VodState copyWith({
    List<VodItem>? items,
    List<String>? categories,
    String? selectedCategory,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearCategory = false,
  }) {
    return VodState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VodNotifier extends Notifier<VodState> {
  bool _disposed = false;

  @override
  VodState build() {
    ref.onDispose(() => _disposed = true);

    // Rebuild when source filter changes.
    ref.watch(effectiveSourceIdsProvider);

    // Sync isFavorite flags when profile favorites change.
    ref.listen(vodFavoritesProvider, (_, next) {
      final favIds = next.asData?.value;
      if (favIds != null && !_disposed) _syncFavorites(favIds);
    });

    // Auto-fetch if starting fresh.
    Future.microtask(() {
      if (!_disposed) refreshFromBackend();
    });

    return VodState(isLoading: true);
  }

  void _syncFavorites(Set<String> favIds) {
    if (state.items.isEmpty) return;
    final updated =
        state.items.map((item) {
          final isFav = favIds.contains(item.id);
          return item.isFavorite != isFav
              ? item.copyWith(isFavorite: isFav)
              : item;
        }).toList();
    state = state.copyWith(items: updated);
  }

  /// Public entry point to apply profile-scoped favorites after
  /// a bulk item load. Used by startup loader and refresh paths
  /// where the [vodFavoritesProvider] listener doesn't fire.
  void applyFavorites(Set<String> favIds) => _syncFavorites(favIds);

  /// Load VOD items and categories.
  void loadData(List<VodItem> items) {
    final cats = <String>{};
    for (final item in items) {
      if (item.category != null && item.category!.isNotEmpty) {
        cats.add(item.category!);
      }
    }
    state = state.copyWith(
      items: items,
      categories: cats.toList()..sort(),
      isLoading: false,
      clearError: true,
    );
  }

  /// Re-loads VOD items from the backend without
  /// wiping UI state.
  ///
  /// Called by the event-driven invalidator when
  /// VOD data changes (e.g. [VodUpdated]).
  Future<void> refreshFromBackend() async {
    final cache = ref.read(cacheServiceProvider);
    final sourceIds = ref.read(effectiveSourceIdsProvider);
    final items =
        sourceIds.isEmpty
            ? await cache.loadVodItems()
            : await cache.getVodBySources(sourceIds);
    if (_disposed) return;
    loadData(items);
    // db_vod_items.is_favorite is reset by playlist syncs
    // (INSERT OR REPLACE). Re-apply from the profile-scoped
    // join table which is the authoritative source.
    final favIds = ref.read(vodFavoritesProvider).value;
    if (favIds != null && favIds.isNotEmpty) {
      _syncFavorites(favIds);
    }
  }

  void selectCategory(String? category) {
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
    );
  }

  void setLoading() {
    state = state.copyWith(isLoading: true, clearError: true);
  }

  void setError(String error) {
    state = state.copyWith(isLoading: false, error: error);
  }

  /// Toggles `isFavorite` on a VOD item via the profile-scoped
  /// [vodFavoritesProvider]. The listener in [build] will sync
  /// the flag back into [VodState.items].
  void toggleFavorite(String itemId) {
    ref.read(vodFavoritesProvider.notifier).toggleFavorite(itemId);
  }
}

/// Global VOD state provider.
final vodProvider = NotifierProvider.autoDispose<VodNotifier, VodState>(
  VodNotifier.new,
);

/// Sort options for VOD grids.
enum VodSortOption {
  recentlyAdded('Recently Added'),
  nameAsc('Name A–Z'),
  nameDesc('Name Z–A'),
  yearDesc('Year (Newest)'),
  ratingDesc('Rating (Highest)');

  const VodSortOption(this.label);
  final String label;

  /// Sort key string expected by the Rust backend's
  /// `sortVodItems` function.
  String get sortByKey => switch (this) {
    VodSortOption.recentlyAdded => 'added_desc',
    VodSortOption.nameAsc => 'name_asc',
    VodSortOption.nameDesc => 'name_desc',
    VodSortOption.yearDesc => 'year_desc',
    VodSortOption.ratingDesc => 'rating_desc',
  };
}

/// Episode progress lookup by series ID.
/// Returns `Map<streamUrl, progress>` where
/// progress is 0.0-1.0.
final episodeProgressMapProvider =
    FutureProvider.family<Map<String, double>, String>((ref, seriesId) async {
      final backend = ref.watch(crispyBackendProvider);
      final resultJson = await backend.computeEpisodeProgressFromDb(seriesId);
      return decodeEpisodeProgress(resultJson).progressMap;
    });

/// Stream URL of the most-recently-watched episode
/// in a series.
final lastWatchedEpisodeIdProvider = FutureProvider.family<String?, String>((
  ref,
  seriesId,
) async {
  final backend = ref.watch(crispyBackendProvider);
  final resultJson = await backend.computeEpisodeProgressFromDb(seriesId);
  return decodeEpisodeProgress(resultJson).lastWatchedUrl;
});

/// Filters VOD items based on active profile's
/// content rating restrictions.
///
/// Uses `.select()` to only rebuild when the items
/// list itself changes, ignoring [VodState] fields
/// like [isLoading] or [selectedCategory].
final filteredVodProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final items = ref.watch(vodProvider.select((s) => s.items));
  final profileState = ref.watch(profileServiceProvider).value;

  if (profileState == null) return items;

  final profile = profileState.activeProfile;

  // No restrictions for unrestricted profiles (or when no profile loaded).
  if (profile == null || !profile.isRestricted) return items;

  return filterByContentRating(items, profile.ratingLevel);
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

/// Movies added in the last [kRecentlyAddedDays] days.
final recentlyAddedMoviesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final items = ref.watch(filteredMoviesProvider);
  return filterRecentlyAdded(items);
});

/// Series added in the last [kRecentlyAddedDays] days.
final recentlyAddedSeriesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final items = ref.watch(filteredSeriesProvider);
  return filterRecentlyAdded(items);
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

/// Returns the set of series item IDs that have been updated within
/// the last [kNewEpisodesDays] days.
///
/// Heuristic: if [VodItem.updatedAt] is more recent than the cutoff, the
/// series likely has new episodes since the playlist was last synced.
/// This requires no backend call — it operates purely on the in-memory
/// [VodState.series] list.
///
/// The set rebuilds only when the series list changes.
final seriesWithNewEpisodesProvider = Provider.autoDispose<Set<String>>((ref) {
  final series = ref.watch(filteredSeriesProvider);
  return seriesIdsWithNewEpisodes(
    series.map((s) => (id: s.id, updatedAt: s.updatedAt)).toList(),
    days: kNewEpisodesDays,
  );
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
        final quality = _resolveQualityFromMap(m);
        return VodSource(
          label: label,
          streamUrl: m['stream_url'] as String? ?? '',
          quality: quality,
        );
      }).toList();
    });

/// Extracts quality badge from a raw VOD map based on URL patterns.
String? _resolveQualityFromMap(Map<String, dynamic> m) {
  final url = m['stream_url'] as String? ?? '';
  if (url.contains('/4k/') || url.contains('4K')) return '4K';
  if (url.contains('/fhd/') || url.contains('FHD') || url.contains('1080')) {
    return 'FHD';
  }
  if (url.contains('/hd/') || url.contains('HD') || url.contains('720')) {
    return 'HD';
  }
  return null;
}
