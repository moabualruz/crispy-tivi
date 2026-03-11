import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/data/dart_algorithm_fallbacks.dart';
import '../../../../core/providers/source_filter_provider.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/vod_utils.dart';
import 'vod_favorites_provider.dart';

// Barrel re-export: derived providers — callers that import vod_providers.dart
// continue to access filteredVodProvider, episodeProgressMapProvider, etc.
// without changing their import statements.
export 'vod_derived_providers.dart';

/// VOD browsing state.
///
/// Derived collections ([movies], [series], [byCategory], etc.)
/// are lazily computed on first access via [late final] getters,
/// so [copyWith] calls (e.g. isLoading toggles) pay zero cost
/// for collections that are never read.
class VodState {
  VodState({
    this.items = const [],
    this.categories = const [],
    this.selectedCategory,
    this.isLoading = false,
    this.error,
  });

  final List<VodItem> items;
  final List<String> categories;
  final String? selectedCategory;
  final bool isLoading;
  final String? error;

  /// Items grouped by category (lazy).
  late final Map<String, List<VodItem>> byCategory = _buildCategoryMap(items);

  /// Items filtered by selected category (lazy).
  late final List<VodItem> filtered =
      selectedCategory == null
          ? items
          : items.where((i) => i.category == selectedCategory).toList();

  /// Featured items for hero banner (lazy).
  late final List<VodItem> featured = featuredItems(items);

  /// New releases sorted by year (lazy).
  late final List<VodItem> newReleases = newReleasesItems(items);

  /// Movie items only (lazy).
  late final List<VodItem> movies =
      items.where((i) => i.type == VodType.movie).toList();

  /// Series items only (lazy).
  late final List<VodItem> series =
      items.where((i) => i.type == VodType.series).toList();

  /// Movie-specific categories (lazy).
  late final List<String> movieCategories = _buildTypeCategories(
    items,
    VodType.movie,
  );

  /// Series-specific categories (lazy).
  late final List<String> seriesCategories = _buildTypeCategories(
    items,
    VodType.series,
  );

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
    return cats.toList()..sort(categoryBucketCompare);
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
    // Reset on re-invocation (watched dependency changed).
    _disposed = false;
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
      categories: cats.toList()..sort(categoryBucketCompare),
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
///
/// Non-autoDispose: VOD data is a root-level cache that lives for
/// the app's lifetime. AutoDispose caused race conditions with the
/// `Future.microtask` in `build()` — the notifier could be disposed
/// before the microtask ran, hanging the UI on `isLoading: true`.
final vodProvider = NotifierProvider<VodNotifier, VodState>(VodNotifier.new);

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
