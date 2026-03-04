part of 'ffi_backend.dart';

/// VOD-related FFI calls.
mixin _FfiVodMixin on _FfiBackendBase {
  // ── VOD Items ────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadVodItems() async {
    final json = await rust_api.loadVodItems();
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
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
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
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
}
