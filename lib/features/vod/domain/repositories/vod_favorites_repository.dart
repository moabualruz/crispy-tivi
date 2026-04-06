/// Repository contract for VOD and category favourite operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class VodFavoritesRepository {
  // ── VOD Favorites ──────────────────────────────────

  /// Get favorite VOD item IDs for [profileId].
  Future<List<String>> getVodFavorites(String profileId);

  /// Add a VOD item to a profile's favorites.
  Future<void> addVodFavorite(String profileId, String vodItemId);

  /// Remove a VOD item from a profile's favorites.
  Future<void> removeVodFavorite(String profileId, String vodItemId);

  // ── Favorite Categories ────────────────────────────

  /// Get favorite category names for [profileId] and [categoryType].
  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  );

  /// Add a category to a profile's favorites.
  Future<void> addFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  );

  /// Remove a category from a profile's favorites.
  Future<void> removeFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  );
}
