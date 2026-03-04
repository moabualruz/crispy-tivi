part of 'crispy_backend.dart';

/// Settings, sync metadata, recordings, storage backends,
/// transfer tasks, image cache, saved layouts, search
/// history, reminders, backup, and Phase 8 service methods.
///
/// Implemented by [CrispyBackend] via `implements`.
abstract class _BackendStorageMethods {
  // ── Settings ─────────────────────────────────────────

  /// Get a setting value by key.
  Future<String?> getSetting(String key);

  /// Set a setting value.
  Future<void> setSetting(String key, String value);

  /// Remove a setting.
  Future<void> removeSetting(String key);

  // ── Sync Metadata ────────────────────────────────────

  /// Get last sync time for a source (Unix seconds).
  Future<int?> getLastSyncTime(String sourceId);

  /// Set last sync time for a source (Unix seconds).
  Future<void> setLastSyncTime(String sourceId, int timestamp);

  // ── Recordings ───────────────────────────────────────

  /// Load all recordings.
  Future<List<Map<String, dynamic>>> loadRecordings();

  /// Save a recording.
  Future<void> saveRecording(Map<String, dynamic> recording);

  /// Update an existing recording.
  Future<void> updateRecording(Map<String, dynamic> recording);

  /// Delete a recording by ID.
  Future<void> deleteRecording(String id);

  /// Fetch commercial markers for a given recording by ID.
  /// Returns a JSON array of CommercialMarker objects.
  Future<String> getRecordingMarkers(String recordingId);

  // ── Storage Backends ─────────────────────────────────

  /// Load all storage backends.
  Future<List<Map<String, dynamic>>> loadStorageBackends();

  /// Save a storage backend.
  Future<void> saveStorageBackend(Map<String, dynamic> backend);

  /// Delete a storage backend by ID.
  Future<void> deleteStorageBackend(String id);

  // ── Transfer Tasks ───────────────────────────────────

  /// Load all transfer tasks.
  Future<List<Map<String, dynamic>>> loadTransferTasks();

  /// Save a transfer task.
  Future<void> saveTransferTask(Map<String, dynamic> task);

  /// Update a transfer task.
  Future<void> updateTransferTask(Map<String, dynamic> task);

  /// Delete a transfer task by ID.
  Future<void> deleteTransferTask(String id);

  // ── Image Cache ──────────────────────────────────────
  // (Removed in Phase 10)

  // ── Saved Layouts ────────────────────────────────────

  /// Load all saved multi-view layouts.
  Future<List<Map<String, dynamic>>> loadSavedLayouts();

  /// Save a multi-view layout.
  Future<void> saveSavedLayout(Map<String, dynamic> layout);

  /// Delete a saved layout by ID.
  Future<void> deleteSavedLayout(String id);

  /// Get a saved layout by ID. Returns null
  /// if not found.
  Future<Map<String, dynamic>?> getSavedLayoutById(String id);

  // ── Search History ───────────────────────────────────

  /// Load all search history entries.
  Future<List<Map<String, dynamic>>> loadSearchHistory();

  /// Save a search history entry.
  Future<void> saveSearchEntry(Map<String, dynamic> entry);

  /// Delete a search history entry by ID.
  Future<void> deleteSearchEntry(String id);

  /// Clear all search history.
  Future<void> clearSearchHistory();

  // ── Reminders ────────────────────────────────────────

  /// Load all reminders.
  Future<List<Map<String, dynamic>>> loadReminders();

  /// Save a reminder.
  Future<void> saveReminder(Map<String, dynamic> reminder);

  /// Delete a reminder by ID.
  Future<void> deleteReminder(String id);

  /// Delete all fired reminders.
  Future<void> clearFiredReminders();

  /// Mark a reminder as fired by ID.
  Future<void> markReminderFired(String id);

  // ── Backup ───────────────────────────────────────────

  /// Export all data as a JSON backup string.
  Future<String> exportBackup();

  /// Import data from a JSON backup string.
  /// Returns summary {profiles: N, ...}.
  Future<Map<String, dynamic>> importBackup(String json);

  // ── Phase 8: Service Methods ─────────────────────────

  /// Update the is_favorite flag on a VOD item.
  Future<void> updateVodFavorite(String itemId, bool isFavorite);

  /// Get profile IDs that have access to a source.
  Future<List<String>> getProfilesForSource(String sourceId);

  /// Delete search history by query text
  /// (case-insensitive). Returns count deleted.
  Future<int> deleteSearchByQuery(String query);

  Future<int> clearAllWatchHistory();
}
