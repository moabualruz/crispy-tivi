import '../entities/vod_item.dart';

/// Repository contract for VOD (video-on-demand) CRUD and filtering operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class VodRepository {
  // ── VOD Items ──────────────────────────────────────

  /// Save VOD items to persistent storage (batch upsert).
  Future<void> saveVodItems(List<VodItem> items);

  /// Load all VOD items.
  Future<List<VodItem>> loadVodItems();

  /// Load VOD items filtered by source IDs.
  ///
  /// Empty [sourceIds] returns all VOD items.
  Future<List<VodItem>> getVodBySources(List<String> sourceIds);

  /// Find VOD alternatives from other sources matching by name and year.
  Future<List<Map<String, dynamic>>> findVodAlternatives(
    String name,
    int year,
    String excludeId,
    int limit,
  );

  /// Get VOD items filtered and sorted directly in the backend.
  ///
  /// [sortByKey] must be one of: `"added_desc"`, `"name_asc"`,
  /// `"name_desc"`, `"year_desc"`, `"rating_desc"`.
  Future<List<VodItem>> getVodFilteredAndSorted({
    required List<String> sourceIds,
    String? itemType,
    String? category,
    String? query,
    required String sortByKey,
  });

  /// Deletes VOD items belonging to [sourceId] that are not
  /// in [keepIds]. Returns the number of deleted items.
  Future<int> deleteRemovedVodItems(String sourceId, Set<String> keepIds);

  // ── Content Filtering ──────────────────────────────

  /// Filter [items] by the given content [ratingLevel].
  Future<List<VodItem>> filterVodByContentRating(
    List<VodItem> items,
    int ratingLevel,
  );

  /// Return items from [items] added within the last [days] days,
  /// relative to [nowMs] (milliseconds since epoch).
  Future<List<VodItem>> filterRecentlyAdded(
    List<VodItem> items,
    int days,
    int nowMs,
  );

  /// Return the set of series item IDs that have been updated within
  /// the last [days] days, relative to [nowMs].
  Future<Set<String>> seriesIdsWithNewEpisodes(
    List<VodItem> series,
    int days,
    int nowMs,
  );
}
