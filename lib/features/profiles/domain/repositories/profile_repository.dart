import '../entities/user_profile.dart';

/// Repository contract for core user profile and profile-scoped
/// preference operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
///
/// Favorites operations are defined in [ProfileFavoritesRepository].
abstract interface class ProfileRepository {
  // ── Profiles ───────────────────────────────────────

  /// Save a user profile (upsert).
  Future<void> saveProfile(UserProfile profile);

  /// Delete a profile and its associated data by [id].
  Future<void> deleteProfile(String id);

  /// Load all user profiles.
  Future<List<UserProfile>> loadProfiles();

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
}
