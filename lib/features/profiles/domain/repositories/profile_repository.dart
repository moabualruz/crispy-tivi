import '../entities/user_profile.dart';

/// Repository contract for user profile and profile-scoped
/// preference operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class ProfileRepository {
  // ── Profiles ───────────────────────────────────────

  /// Save a user profile (upsert).
  Future<void> saveProfile(UserProfile profile);

  /// Delete a profile and its associated data by [id].
  Future<void> deleteProfile(String id);

  /// Load all user profiles.
  Future<List<UserProfile>> loadProfiles();

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

  // ── Source Access ──────────────────────────────────

  /// Grant a profile access to a source.
  Future<void> grantSourceAccess(String profileId, String sourceId);

  /// Revoke a profile's access to a source.
  Future<void> revokeSourceAccess(String profileId, String sourceId);

  /// Get all source IDs accessible to [profileId].
  Future<List<String>> getSourceAccess(String profileId);

  /// Set source access for [profileId], replacing any existing list.
  Future<void> setSourceAccess(String profileId, List<String> sourceIds);

  /// Get all profile IDs with access to [sourceId].
  Future<List<String>> getProfilesWithSourceAccess(String sourceId);

  // ── Channel Custom Order ───────────────────────────

  /// Save a custom channel order for a specific group and profile.
  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  );

  /// Load the custom channel order for a specific group and profile.
  ///
  /// Returns null when no custom order has been saved.
  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  );

  /// Reset the custom channel order for a specific group and profile.
  Future<void> resetChannelOrder(String profileId, String groupName);

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
