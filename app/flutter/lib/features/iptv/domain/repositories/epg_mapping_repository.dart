/// Repository contract for EPG channel-ID mapping operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class EpgMappingRepository {
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
}
