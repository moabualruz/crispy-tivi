import '../entities/recording.dart';
import '../entities/storage_backend.dart';
import '../entities/transfer_task.dart';
import '../entities/commercial_marker.dart';

/// Repository contract for DVR recording, storage backend, and
/// transfer task operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class DvrRepository {
  // ── Recordings ─────────────────────────────────────

  /// Load all recordings.
  Future<List<Recording>> loadRecordings();

  /// Save (insert or replace) a recording.
  Future<void> saveRecording(Recording recording);

  /// Update a recording's status and file info.
  Future<void> updateRecording(Recording recording);

  /// Delete a recording by [id].
  Future<void> deleteRecording(String id);

  /// Get commercial markers for [recordingId].
  Future<List<CommercialMarker>> getRecordingMarkers(String recordingId);

  // ── Storage Backends ───────────────────────────────

  /// Load all configured storage backends.
  Future<List<StorageBackend>> loadStorageBackends();

  /// Save (insert or replace) a storage backend.
  Future<void> saveStorageBackend(StorageBackend backend);

  /// Delete a storage backend by [id].
  Future<void> deleteStorageBackend(String id);

  // ── Transfer Tasks ─────────────────────────────────

  /// Load all transfer tasks.
  Future<List<TransferTask>> loadTransferTasks();

  /// Save (insert or replace) a transfer task.
  Future<void> saveTransferTask(TransferTask task);

  /// Update a transfer task's status and progress.
  Future<void> updateTransferTask(TransferTask task);

  /// Delete a transfer task by [id].
  Future<void> deleteTransferTask(String id);
}
