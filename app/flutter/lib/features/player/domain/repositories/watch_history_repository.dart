import '../entities/watch_history_entry.dart';

/// Repository contract for watch history persistence.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class WatchHistoryRepository {
  // ── Watch History ──────────────────────────────────

  /// Load all watch history entries.
  Future<List<WatchHistoryEntry>> loadWatchHistory();

  /// Save a watch history entry (upsert).
  Future<void> saveWatchHistory(WatchHistoryEntry entry);

  /// Delete a watch history entry by [id].
  Future<void> deleteWatchHistory(String id);

  /// Clear all watch history.
  Future<void> clearAllWatchHistory();
}
