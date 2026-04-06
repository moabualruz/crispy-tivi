/// Repository contract for profile-scoped favorites operations.
///
/// Covers channel favorites, VOD favorites, and favorite categories.
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
///
/// Core profile and source-access operations are defined in
/// [ProfileRepository].
abstract interface class ProfileFavoritesRepository {
  // ── Channel Favorites ──────────────────────────────

  /// Add a channel to a profile's favorites.
  Future<void> addFavorite(String profileId, String channelId);

  /// Remove a channel from a profile's favorites.
  Future<void> removeFavorite(String profileId, String channelId);

  /// Get favorite channel IDs for [profileId].
  Future<List<String>> getFavorites(String profileId);

  // ── VOD Favorites ──────────────────────────────────

  /// Add a VOD item to a profile's favorites.
  Future<void> addVodFavorite(String profileId, String vodItemId);

  /// Remove a VOD item from a profile's favorites.
  Future<void> removeVodFavorite(String profileId, String vodItemId);

  /// Get favorite VOD item IDs for [profileId].
  Future<List<String>> getVodFavorites(String profileId);

  // ── Favorite Categories ────────────────────────────

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

  /// Get favorite category names for [profileId] and [categoryType].
  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  );
}
