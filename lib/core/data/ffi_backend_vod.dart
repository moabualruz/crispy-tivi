part of 'ffi_backend.dart';

/// VOD-related FFI calls.
mixin _FfiVodMixin on _FfiBackendBase {
  // ── VOD Items ────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadVodItems() async {
    final json = await rust_api.loadVodItems();
    return _decodeJsonList(json);
  }

  Future<int> saveVodItems(List<Map<String, dynamic>> items) async {
    final result = await rust_api.saveVodItems(json: jsonEncode(items));
    return result.toInt();
  }

  Future<int> deleteRemovedVodItems(
    String sourceId,
    List<String> keepIds,
  ) async {
    final result = await rust_api.deleteRemovedVodItems(
      sourceId: sourceId,
      keepIds: keepIds,
    );
    return result.toInt();
  }

  Future<List<Map<String, dynamic>>> getVodBySources(
    List<String> sourceIds,
  ) async {
    final json = await rust_api.getVodBySources(
      sourceIdsJson: jsonEncode(sourceIds),
    );
    return _decodeJsonList(json);
  }

  Future<String> getVodPage(
    String sourceIdsJson, {
    String? itemType,
    String? category,
    String? query,
    required String sort,
    required int offset,
    required int limit,
  }) => rust_api.getVodPage(
    sourceIdsJson: sourceIdsJson,
    vodType: itemType,
    category: category,
    query: query,
    sort: sort,
    offset: PlatformInt64Util.from(offset),
    limit: PlatformInt64Util.from(limit),
  );

  Future<int> getVodCount(
    String sourceIdsJson, {
    String? itemType,
    String? category,
    String? query,
  }) async {
    final result = await rust_api.getVodCount(
      sourceIdsJson: sourceIdsJson,
      vodType: itemType,
      category: category,
      query: query,
    );
    return result;
  }

  Future<String> getVodCategories(
    String sourceIdsJson, {
    String? itemType,
  }) => rust_api.getVodCategories(
    sourceIdsJson: sourceIdsJson,
    vodType: itemType,
  );

  Future<String> searchVod(
    String query,
    String sourceIdsJson,
    int offset,
    int limit,
  ) => rust_api.searchVod(
    query: query,
    sourceIdsJson: sourceIdsJson,
    offset: PlatformInt64Util.from(offset),
    limit: PlatformInt64Util.from(limit),
  );

  Future<String> getFilteredVod(
    String sourceIdsJson, {
    String? itemType,
    String? category,
    String? query,
    required String sortBy,
  }) async {
    return await rust_api.getFilteredVod(
      sourceIdsJson: sourceIdsJson,
      itemType: itemType,
      category: category,
      query: query,
      sortBy: sortBy,
    );
  }

  Future<String> filterAndSortVodItems(
    String itemsJson, {
    String? category,
    String? query,
    required String sortBy,
  }) async {
    return rust_api.filterAndSortVodItems(
      itemsJson: itemsJson,
      category: category,
      query: query,
      sortBy: sortBy,
    );
  }

  // ── VOD Favorites ────────────────────────────────

  Future<List<String>> getVodFavorites(String profileId) =>
      rust_api.getVodFavorites(profileId: profileId);

  Future<void> addVodFavorite(String profileId, String vodItemId) =>
      rust_api.addVodFavorite(profileId: profileId, vodItemId: vodItemId);

  Future<void> removeVodFavorite(String profileId, String vodItemId) =>
      rust_api.removeVodFavorite(profileId: profileId, vodItemId: vodItemId);

  // ── Watchlist ────────────────────────────────

  Future<List<Map<String, dynamic>>> getWatchlistItems(String profileId) async {
    final json = await rust_api.getWatchlistItems(profileId: profileId);
    return _decodeJsonList(json);
  }

  Future<void> addWatchlistItem(String profileId, String vodItemId) =>
      rust_api.addWatchlistItem(profileId: profileId, vodItemId: vodItemId);

  Future<void> removeWatchlistItem(String profileId, String vodItemId) =>
      rust_api.removeWatchlistItem(profileId: profileId, vodItemId: vodItemId);

  // ── Phase 8: VOD Service ─────────────────────────

  Future<void> updateVodFavorite(String itemId, bool isFavorite) =>
      rust_api.updateVodFavorite(itemId: itemId, isFavorite: isFavorite);

  // ── VOD Categories ─────────────────────────────

  Future<String> resolveVodCategories(String itemsJson, String catMapJson) =>
      rust_api.resolveVodCategories(
        itemsJson: itemsJson,
        catMapJson: catMapJson,
      );

  Future<List<String>> extractSortedVodCategories(String itemsJson) =>
      rust_api.extractSortedVodCategories(itemsJson: itemsJson);

  Future<List<Map<String, dynamic>>> findVodAlternatives(
    String name,
    int year,
    String excludeId,
    int limit,
  ) async {
    final json = await rust_api.findVodAlternatives(
      name: name,
      year: year,
      excludeId: excludeId,
      limit: BigInt.from(limit),
    );
    return _decodeJsonList(json);
  }
}
