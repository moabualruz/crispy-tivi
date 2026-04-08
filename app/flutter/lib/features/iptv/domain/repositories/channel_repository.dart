import '../entities/channel.dart';

/// Repository contract for channel CRUD operations.
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
}
