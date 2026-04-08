/// Repository contract for smart group operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class SmartGroupRepository {
  // ── Smart Groups ────────────────────────────────────

  /// Return all smart groups as raw JSON maps.
  Future<List<Map<String, dynamic>>> getSmartGroupsParsed();

  /// Return auto-detected smart group candidates as raw JSON maps.
  Future<List<Map<String, dynamic>>> getSmartGroupCandidatesParsed();
}
