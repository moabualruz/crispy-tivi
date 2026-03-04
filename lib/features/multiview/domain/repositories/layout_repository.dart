import '../entities/saved_layout.dart';

/// Repository interface for persisting Multi-View layouts.
abstract interface class LayoutRepository {
  /// Get all saved layouts, ordered by creation date (newest first).
  Future<List<SavedLayout>> getAll();

  /// Get a specific layout by ID.
  Future<SavedLayout?> getById(String id);

  /// Save or update a layout.
  Future<void> save(SavedLayout layout);

  /// Delete a layout by ID.
  Future<void> delete(String id);

  /// Generate a unique layout ID.
  ///
  /// Centralises ID generation in the data layer so callers do not
  /// need to know the ID scheme.
  String generateId();
}
