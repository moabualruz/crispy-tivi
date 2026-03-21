part of 'crispy_backend.dart';

/// Channel/VOD CRUD, favorites, categories, profiles,
/// source access, channel order, EPG, and watch history.
///
/// Implemented by [CrispyBackend] via `implements`.
abstract class _BackendDataMethods {
  // ── Channels ─────────────────────────────────────────

  /// Load all channels.
  Future<List<Map<String, dynamic>>> loadChannels();

  /// Save channels. Returns count saved.
  Future<int> saveChannels(List<Map<String, dynamic>> channels);

  /// Load channels by their IDs.
  Future<List<Map<String, dynamic>>> getChannelsByIds(List<String> ids);

  /// Delete channels not in [keepIds] for [sourceId].
  /// Returns count deleted.
  Future<int> deleteRemovedChannels(String sourceId, List<String> keepIds);

  /// Load channels filtered by source IDs.
  /// Empty [sourceIds] returns all channels.
  Future<List<Map<String, dynamic>>> getChannelsBySources(
    List<String> sourceIds,
  );

  // ── Channel Favorites ────────────────────────────────

  /// Get favourite channel IDs for a profile.
  Future<List<String>> getFavorites(String profileId);

  /// Add a channel to profile favourites.
  Future<void> addFavorite(String profileId, String channelId);

  /// Remove a channel from profile favourites.
  Future<void> removeFavorite(String profileId, String channelId);

  // ── VOD Items ────────────────────────────────────────

  /// Load all VOD items.
  Future<List<Map<String, dynamic>>> loadVodItems();

  /// Save VOD items. Returns count saved.
  Future<int> saveVodItems(List<Map<String, dynamic>> items);

  /// Delete VOD items not in [keepIds] for [sourceId].
  /// Returns count deleted.
  Future<int> deleteRemovedVodItems(String sourceId, List<String> keepIds);

  /// Load VOD items filtered by source IDs.
  /// Empty [sourceIds] returns all VOD items.
  Future<List<Map<String, dynamic>>> getVodBySources(List<String> sourceIds);

  /// Find VOD alternatives from other sources matching by name + year.
  /// [year] = 0 means "no year filter".
  Future<List<Map<String, dynamic>>> findVodAlternatives(
    String name,
    int year,
    String excludeId,
    int limit,
  );

  /// Load VOD items filtered by source IDs, type, category, query, and sort key.
  Future<String> getFilteredVod(
    String sourceIdsJson, {
    String? itemType,
    String? category,
    String? query,
    required String sortBy,
  });

  /// Filter and sort an in-memory VOD items array on Rust side.
  Future<String> filterAndSortVodItems(
    String itemsJson, {
    String? category,
    String? query,
    required String sortBy,
  });

  // ── VOD Favorites ────────────────────────────────────

  /// Get favourite VOD item IDs for a profile.
  Future<List<String>> getVodFavorites(String profileId);

  /// Add a VOD item to profile favourites.
  Future<void> addVodFavorite(String profileId, String vodItemId);

  /// Remove a VOD item from profile favourites.
  Future<void> removeVodFavorite(String profileId, String vodItemId);

  // ── Watchlist ───────────────────────────────────────

  /// Get watchlist items for a profile.
  Future<List<Map<String, dynamic>>> getWatchlistItems(String profileId);

  /// Add a VOD item to the profile's watchlist.
  Future<void> addWatchlistItem(String profileId, String vodItemId);

  /// Remove a VOD item from the profile's watchlist.
  Future<void> removeWatchlistItem(String profileId, String vodItemId);

  // ── Categories ───────────────────────────────────────

  /// Load categories as {type: [names]}.
  Future<Map<String, List<String>>> loadCategories();

  /// Save categories from {type: [names]}.
  Future<void> saveCategories(Map<String, List<String>> categories);

  /// Load categories filtered by source IDs.
  /// Empty [sourceIds] returns all categories.
  Future<Map<String, List<String>>> getCategoriesBySources(
    List<String> sourceIds,
  );

  // ── Category Favorites ───────────────────────────────

  /// Get favourite category names for profile + type.
  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  );

  /// Add a category to profile favourites.
  Future<void> addFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  );

  /// Remove a category from profile favourites.
  Future<void> removeFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  );

  // ── Profiles ─────────────────────────────────────────

  /// Load all profiles.
  Future<List<Map<String, dynamic>>> loadProfiles();

  /// Save a profile.
  Future<void> saveProfile(Map<String, dynamic> profile);

  /// Delete a profile and cascade-delete children.
  Future<void> deleteProfile(String id);

  // ── Source Access ────────────────────────────────────

  /// Get source IDs a profile can access.
  Future<List<String>> getSourceAccess(String profileId);

  /// Grant a profile access to a source.
  Future<void> grantSourceAccess(String profileId, String sourceId);

  /// Revoke a profile's access to a source.
  Future<void> revokeSourceAccess(String profileId, String sourceId);

  /// Replace all source access for a profile.
  Future<void> setSourceAccess(String profileId, List<String> sourceIds);

  // ── Channel Order ────────────────────────────────────

  /// Save custom channel order for profile + group.
  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  );

  /// Load channel order as {channelId: index},
  /// or null if no custom order.
  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  );

  /// Reset channel order for profile + group.
  Future<void> resetChannelOrder(String profileId, String groupName);

  // ── EPG ──────────────────────────────────────────────

  /// Fetch exactly the programs airing within [start] and [end]
  /// for the specified [channelIds]. Returns a map grouped by channel_id.
  Future<Map<String, List<Map<String, dynamic>>>> getEpgsForChannels(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  );

  /// Load EPG entries filtered by source IDs.
  /// Empty [sourceIds] returns all EPG entries.
  Future<Map<String, List<Map<String, dynamic>>>> getEpgBySources(
    List<String> sourceIds,
  );

  /// Fetch EPG via the 3-layer facade (L1 hot cache → L2 SQLite → L3 API).
  Future<Map<String, List<Map<String, dynamic>>>> getChannelsEpg(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  );

  /// Load EPG entries as {channelId: [entries]}.
  Future<Map<String, List<Map<String, dynamic>>>> loadEpgEntries();

  /// Save EPG entries from {channelId: [entries]}.
  /// Returns count saved.
  Future<int> saveEpgEntries(Map<String, List<Map<String, dynamic>>> entries);

  /// Delete EPG entries older than [days].
  /// Returns count deleted.
  Future<int> evictStaleEpg(int days);

  /// Delete all EPG entries.
  Future<void> clearEpgEntries();

  /// Trigger asynchronous XMLTV download and mapping on Rust backend.
  Future<int> syncXmltvEpg({required String url});

  /// Trigger asynchronous Xtream short EPG fetch and mapping on Rust backend.
  Future<int> syncXtreamEpg({
    required String baseUrl,
    required String username,
    required String password,
    required String channelsJson,
  });

  /// Trigger asynchronous Stalker short EPG fetch and mapping on Rust backend.
  Future<int> syncStalkerEpg({
    required String baseUrl,
    required String channelsJson,
  });

  // ── EPG Mappings ────────────────────────────────────

  /// Save an EPG mapping.
  Future<void> saveEpgMapping(Map<String, dynamic> mapping);

  /// Get all EPG mappings.
  Future<List<Map<String, dynamic>>> getEpgMappings();

  /// Lock an EPG mapping so it won't be overridden.
  Future<void> lockEpgMapping(String channelId);

  /// Delete an EPG mapping.
  Future<void> deleteEpgMapping(String channelId);

  /// Get pending EPG suggestions (0.40-0.69 confidence, not locked).
  Future<List<Map<String, dynamic>>> getPendingEpgSuggestions();

  /// Mark a channel as 24/7.
  Future<void> setChannel247(String channelId, {required bool is247});

  // ── Watch History ────────────────────────────────────

  /// Load all watch history entries.
  Future<List<Map<String, dynamic>>> loadWatchHistory();

  /// Save a watch history entry.
  Future<void> saveWatchHistory(Map<String, dynamic> entry);

  /// Delete a watch history entry by ID.
  Future<void> deleteWatchHistory(String id);
}
