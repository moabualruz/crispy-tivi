part of 'cache_service.dart';

/// Profile, favorites, source access, and channel
/// order methods for [CacheService].
mixin _CacheProfilesMixin on _CacheServiceBase {
  // ── Profiles ──────────────────────────────────────

  /// Save a user profile (upsert).
  Future<void> saveProfile(UserProfile profile) async {
    await _backend.saveProfile(_profileToMap(profile));
  }

  /// Delete a profile and its associated data.
  Future<void> deleteProfile(String id) async {
    await _backend.deleteProfile(id);
  }

  /// Load all user profiles.
  Future<List<UserProfile>> loadProfiles() async {
    final maps = await _backend.loadProfiles();
    return maps.map(_mapToProfile).toList();
  }

  // ── Profile Favorites ─────────────────────────────

  /// Add a channel to profile favorites.
  Future<void> addFavorite(String profileId, String channelId) async {
    await _backend.addFavorite(profileId, channelId);
  }

  /// Remove a channel from profile favorites.
  Future<void> removeFavorite(String profileId, String channelId) async {
    await _backend.removeFavorite(profileId, channelId);
  }

  /// Get favorite channel IDs for a profile.
  Future<List<String>> getFavorites(String profileId) async {
    return _backend.getFavorites(profileId);
  }

  // ── VOD Favorites (Profile-Scoped) ────────────────

  /// Add a VOD item to profile favorites.
  Future<void> addVodFavorite(String profileId, String vodItemId) async {
    await _backend.addVodFavorite(profileId, vodItemId);
  }

  /// Remove a VOD item from profile favorites.
  Future<void> removeVodFavorite(String profileId, String vodItemId) async {
    await _backend.removeVodFavorite(profileId, vodItemId);
  }

  /// Get favorite VOD item IDs for a profile.
  Future<List<String>> getVodFavorites(String profileId) async {
    return _backend.getVodFavorites(profileId);
  }

  // ── Watchlist (Profile-Scoped) ─────────────────────

  /// Get watchlist items for a profile.
  Future<List<VodItem>> getWatchlistItems(String profileId) async {
    final maps = await _backend.getWatchlistItems(profileId);
    return maps.map(mapToVodItem).toList();
  }

  /// Add a VOD item to the profile's watchlist.
  Future<void> addWatchlistItem(String profileId, String vodItemId) async {
    await _backend.addWatchlistItem(profileId, vodItemId);
  }

  /// Remove a VOD item from the profile's watchlist.
  Future<void> removeWatchlistItem(String profileId, String vodItemId) async {
    await _backend.removeWatchlistItem(profileId, vodItemId);
  }

  // ── Favorite Categories (Profile-Scoped) ──────────

  /// Add a category to profile favorites.
  Future<void> addFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) async {
    await _backend.addFavoriteCategory(profileId, categoryType, categoryName);
  }

  /// Remove a category from profile favorites.
  Future<void> removeFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) async {
    await _backend.removeFavoriteCategory(
      profileId,
      categoryType,
      categoryName,
    );
  }

  /// Get favorite category names for a profile
  /// and type.
  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  ) async {
    return _backend.getFavoriteCategories(profileId, categoryType);
  }

  // ── Profile Source Access ─────────────────────────

  /// Grant a profile access to a source.
  Future<void> grantSourceAccess(String profileId, String sourceId) async {
    await _backend.grantSourceAccess(profileId, sourceId);
  }

  /// Revoke a profile's access to a source.
  Future<void> revokeSourceAccess(String profileId, String sourceId) async {
    await _backend.revokeSourceAccess(profileId, sourceId);
  }

  /// Get all source IDs a profile has access to.
  Future<List<String>> getSourceAccess(String profileId) async {
    return _backend.getSourceAccess(profileId);
  }

  /// Set source access for a profile (replaces).
  Future<void> setSourceAccess(String profileId, List<String> sourceIds) async {
    await _backend.setSourceAccess(profileId, sourceIds);
  }

  /// Get all profiles with access to a source.
  Future<List<String>> getProfilesWithSourceAccess(String sourceId) async {
    return _backend.getProfilesForSource(sourceId);
  }

  // ── Channel Custom Order ──────────────────────────

  /// Saves custom channel order for a specific
  /// group and profile.
  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  ) async {
    await _backend.saveChannelOrder(profileId, groupName, channelIds);
  }

  /// Loads custom channel order for a specific
  /// group and profile.
  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  ) async {
    return _backend.loadChannelOrder(profileId, groupName);
  }

  /// Resets channel order for a specific group
  /// and profile.
  Future<void> resetChannelOrder(String profileId, String groupName) async {
    await _backend.resetChannelOrder(profileId, groupName);
  }
}

// ── Profile converters (top-level, private) ───────

UserProfile _mapToProfile(Map<String, dynamic> m) {
  return UserProfile(
    id: m['id'] as String,
    name: m['name'] as String,
    avatarIndex: m['avatar_index'] as int? ?? 0,
    pin: m['pin'] as String?,
    isChild: m['is_child'] as bool? ?? false,
    // FE-PM-10: guest profile flag; defaults false for legacy data.
    isGuest: m['is_guest'] as bool? ?? false,
    pinVersion: m['pin_version'] as int? ?? 0,
    maxAllowedRating: m['max_allowed_rating'] as int? ?? 4,
    role: _parseRole(m['role']),
    dvrPermission: _parseDvrPermission(m['dvr_permission']),
    dvrQuotaMB: m['dvr_quota_mb'] as int?,
    // FE-PM-08: per-profile accent color override.
    accentColorValue: m['accent_color_value'] as int?,
    // FE-PM-07: per-profile language / subtitle defaults.
    preferredAudioLanguage: m['preferred_audio_language'] as String?,
    preferredSubtitleLanguage: m['preferred_subtitle_language'] as String?,
    subtitleEnabledByDefault:
        m['subtitle_enabled_by_default'] as bool? ?? false,
    isActive: false,
  );
}

/// Parse role from either string ("admin") or int (0) for backward compat.
/// Case-insensitive to handle Rust serialization differences.
UserRole _parseRole(dynamic v) {
  if (v is String) {
    final lower = v.toLowerCase();
    return UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == lower,
      orElse: () => UserRole.viewer,
    );
  }
  return UserRole.fromValue(v as int? ?? 1);
}

/// Parse DVR permission from either string ("full") or int (2).
/// Case-insensitive to handle Rust serialization differences.
DvrPermission _parseDvrPermission(dynamic v) {
  if (v is String) {
    final lower = v.toLowerCase();
    return DvrPermission.values.firstWhere(
      (p) => p.name.toLowerCase() == lower,
      orElse: () => DvrPermission.viewOnly,
    );
  }
  return DvrPermission.fromValue(v as int? ?? 2);
}

Map<String, dynamic> _profileToMap(UserProfile p) {
  return {
    'id': p.id,
    'name': p.name,
    'avatar_index': p.avatarIndex,
    'pin': p.pin,
    'is_child': p.isChild,
    // FE-PM-10: guest profile flag.
    'is_guest': p.isGuest,
    'pin_version': p.pinVersion,
    'max_allowed_rating': p.maxAllowedRating,
    'role': p.role.name,
    'dvr_permission': p.dvrPermission.name.toLowerCase(),
    'dvr_quota_mb': p.dvrQuotaMB,
    // FE-PM-08: per-profile accent color override.
    'accent_color_value': p.accentColorValue,
    // FE-PM-07: per-profile language / subtitle defaults.
    'preferred_audio_language': p.preferredAudioLanguage,
    'preferred_subtitle_language': p.preferredSubtitleLanguage,
    'subtitle_enabled_by_default': p.subtitleEnabledByDefault,
  };
}
