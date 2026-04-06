import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';

export '../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, crispyBackendProvider;
import '../domain/entities/vod_item.dart';
import '../domain/repositories/vod_repository.dart';

/// CacheService-backed implementation of [VodRepository].
class VodRepositoryImpl implements VodRepository {
  VodRepositoryImpl(this._cache);

  final CacheService _cache;

  // ── VOD Items ──────────────────────────────────────

  @override
  Future<void> saveVodItems(List<VodItem> items) => _cache.saveVodItems(items);

  @override
  Future<List<VodItem>> loadVodItems() => _cache.loadVodItems();

  @override
  Future<List<VodItem>> getVodBySources(List<String> sourceIds) =>
      _cache.getVodBySources(sourceIds);

  @override
  Future<void> updateVodFavorite(String itemId, bool isFavorite) =>
      _cache.updateVodFavorite(itemId, isFavorite);

  @override
  Future<List<Map<String, dynamic>>> findVodAlternatives(
    String name,
    int year,
    String excludeId,
    int limit,
  ) => _cache.findVodAlternatives(name, year, excludeId, limit);

  @override
  Future<List<VodItem>> getVodFilteredAndSorted({
    required List<String> sourceIds,
    String? itemType,
    String? category,
    String? query,
    required String sortByKey,
  }) => _cache.getVodFilteredAndSorted(
    sourceIds: sourceIds,
    itemType: itemType,
    category: category,
    query: query,
    sortByKey: sortByKey,
  );

  @override
  Future<int> deleteRemovedVodItems(String sourceId, Set<String> keepIds) =>
      _cache.deleteRemovedVodItems(sourceId, keepIds);

  // ── Content Filtering ──────────────────────────────

  @override
  Future<List<VodItem>> filterVodByContentRating(
    List<VodItem> items,
    int ratingLevel,
  ) => _cache.filterVodByContentRating(items, ratingLevel);

  @override
  Future<List<VodItem>> filterRecentlyAdded(
    List<VodItem> items,
    int days,
    int nowMs,
  ) => _cache.filterRecentlyAdded(items, days, nowMs);

  @override
  Future<Set<String>> seriesIdsWithNewEpisodes(
    List<VodItem> series,
    int days,
    int nowMs,
  ) => _cache.seriesIdsWithNewEpisodes(series, days, nowMs);

  // ── VOD Favorites ──────────────────────────────────

  @override
  Future<List<String>> getVodFavorites(String profileId) =>
      _cache.getVodFavorites(profileId);

  @override
  Future<void> addVodFavorite(String profileId, String vodItemId) =>
      _cache.addVodFavorite(profileId, vodItemId);

  @override
  Future<void> removeVodFavorite(String profileId, String vodItemId) =>
      _cache.removeVodFavorite(profileId, vodItemId);

  // ── Favorite Categories ────────────────────────────

  @override
  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  ) => _cache.getFavoriteCategories(profileId, categoryType);

  @override
  Future<void> addFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) => _cache.addFavoriteCategory(profileId, categoryType, categoryName);

  @override
  Future<void> removeFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) => _cache.removeFavoriteCategory(profileId, categoryType, categoryName);

  // ── Key-Value Settings ─────────────────────────────

  @override
  Future<String?> getSetting(String key) => _cache.getSetting(key);

  @override
  Future<void> setSetting(String key, String value) =>
      _cache.setSetting(key, value);

  @override
  Future<void> removeSetting(String key) => _cache.removeSetting(key);
}

/// Riverpod provider for [VodRepository].
final vodRepositoryProvider = Provider<VodRepository>((ref) {
  return VodRepositoryImpl(ref.watch(cacheServiceProvider));
});
