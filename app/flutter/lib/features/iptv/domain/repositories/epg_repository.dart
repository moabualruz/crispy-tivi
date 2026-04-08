import '../entities/epg_entry.dart';

/// Repository contract for EPG (program guide) data operations.
///
/// Implemented by infrastructure layer with local ObjectBox
/// storage and XMLTV parser.
abstract interface class EpgRepository {
  /// Returns EPG entries for a channel within a date range.
  Future<List<EpgEntry>> getPrograms({
    required String channelId,
    required DateTime from,
    required DateTime to,
  });

  /// Returns the currently-airing programme for a channel.
  Future<EpgEntry?> getNowPlaying(String channelId);

  /// Returns the next N upcoming programmes for a channel.
  Future<List<EpgEntry>> getUpcoming(String channelId, {int limit = 5});

  /// Fuzzy search across programme titles and descriptions.
  Future<List<EpgEntry>> search(String query);

  /// Deletes EPG entries older than [maxAge].
  Future<int> evictStale(Duration maxAge);

  // ── EPG CRUD ───────────────────────────────────────

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
}
