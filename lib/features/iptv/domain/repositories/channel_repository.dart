import '../entities/channel.dart';
import '../entities/epg_entry.dart';

/// Repository contract for channel and EPG data operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class ChannelRepository {
  // ── Channels ───────────────────────────────────────

  /// Save channels to persistent storage (batch upsert).
  Future<void> saveChannels(List<Channel> channels);

  /// Load all channels.
  Future<List<Channel>> loadChannels();

  /// Load specific channels by their IDs.
  Future<List<Channel>> getChannelsByIds(List<String> ids);

  /// Load channels filtered by source IDs.
  ///
  /// Empty [sourceIds] returns all channels.
  Future<List<Channel>> getChannelsBySources(List<String> sourceIds);

  /// Load categories (group names) filtered by source IDs.
  ///
  /// Empty [sourceIds] returns all categories.
  Future<Map<String, List<String>>> getCategoriesBySources(
    List<String> sourceIds,
  );

  /// Deletes channels belonging to [sourceId] that are not
  /// in [keepIds]. Returns the number of deleted channels.
  Future<int> deleteRemovedChannels(String sourceId, Set<String> keepIds);

  // ── EPG ────────────────────────────────────────────

  /// Fetch EPG entries for [channelIds] within [start] and [end].
  Future<Map<String, List<EpgEntry>>> getEpgsForChannels(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  );

  /// Fetch EPG via the 3-layer facade
  /// (L1 hot cache → L2 SQLite → L3 API).
  Future<Map<String, List<EpgEntry>>> getChannelsEpg(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  );

  /// Save EPG entries grouped by channel ID (upsert).
  Future<void> saveEpgEntries(Map<String, List<EpgEntry>> entriesByChannel);

  /// Load all EPG entries grouped by channel ID.
  Future<Map<String, List<EpgEntry>>> loadEpgEntries();

  /// Evict EPG entries older than [days] days.
  ///
  /// Returns the number of evicted entries.
  Future<int> evictStaleEpgEntries({int days = 2});

  /// Clear all EPG entries.
  Future<void> clearEpgEntries();

  // ── EPG Mappings ────────────────────────────────────

  /// Save an EPG channel-ID mapping.
  Future<void> saveEpgMapping(Map<String, dynamic> mapping);

  /// Get all EPG channel-ID mappings.
  Future<List<Map<String, dynamic>>> getEpgMappings();

  /// Lock an EPG mapping so it is not overridden by auto-matching.
  Future<void> lockEpgMapping(String channelId);

  /// Delete an EPG mapping for [channelId].
  Future<void> deleteEpgMapping(String channelId);

  /// Get pending EPG suggestions (confidence 0.40–0.69, not locked).
  Future<List<Map<String, dynamic>>> getPendingEpgSuggestions();

  /// Mark or unmark a channel as 24/7.
  Future<void> setChannel247(String channelId, {required bool is247});

  // ── Channel Ordering ────────────────────────────────

  /// Extract a sorted, deduplicated list of group names from [channels].
  Future<List<String>> extractSortedGroups(List<Channel> channels);

  /// Save a custom channel order for [profileId] and [groupName].
  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  );

  /// Load the custom channel order for [profileId] and [groupName].
  ///
  /// Returns null when no custom order has been saved.
  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  );

  /// Reset the custom channel order for [profileId] and [groupName].
  Future<void> resetChannelOrder(String profileId, String groupName);

  // ── EPG-aware Search ───────────────────────────────

  /// Return channel IDs whose currently-airing program title matches [query].
  Future<List<String>> searchChannelsByLiveProgram(
    Map<String, List<EpgEntry>> epgEntries,
    String query,
    int nowMs,
  );

  /// Merge EPG-matched channels into the base filtered list.
  Future<List<Channel>> mergeEpgMatchedChannels({
    required List<Channel> baseChannels,
    required List<Channel> allChannels,
    required List<String> matchedIds,
    required Map<String, String> epgOverrides,
  });

  // ── Smart Groups ────────────────────────────────────

  /// Return all smart groups as raw JSON maps.
  Future<List<Map<String, dynamic>>> getSmartGroupsParsed();

  /// Return auto-detected smart group candidates as raw JSON maps.
  Future<List<Map<String, dynamic>>> getSmartGroupCandidatesParsed();
}
