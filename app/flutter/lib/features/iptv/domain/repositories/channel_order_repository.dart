import '../entities/channel.dart';

/// Repository contract for channel ordering operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class ChannelOrderRepository {
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
}
