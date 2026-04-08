part of 'memory_backend.dart';

/// Recordings, storage backends, and transfer
/// task methods for [MemoryBackend].
mixin _MemoryDvrMixin on _MemoryStorage {
  // ── Recordings ─────────────────────────────────

  Future<List<Map<String, dynamic>>> loadRecordings() async =>
      recordings.values.toList();

  Future<void> saveRecording(Map<String, dynamic> recording) async {
    recordings[recording['id'] as String] = recording;
  }

  Future<void> updateRecording(Map<String, dynamic> recording) async {
    recordings[recording['id'] as String] = recording;
  }

  Future<void> deleteRecording(String id) async {
    recordings.remove(id);
  }

  Future<String> getRecordingMarkers(
    String recordingId,
  ) => Future<String>.error(
    UnimplementedError(
      'Recording marker analysis is not implemented for `$recordingId` on MemoryBackend',
    ),
  );

  // ── Storage Backends ──────────────────────────

  Future<List<Map<String, dynamic>>> loadStorageBackends() async =>
      storageBackends.values.toList();

  Future<void> saveStorageBackend(Map<String, dynamic> backend) async {
    storageBackends[backend['id'] as String] = backend;
  }

  Future<void> deleteStorageBackend(String id) async {
    storageBackends.remove(id);
  }

  // ── Transfer Tasks ─────────────────────────────

  Future<List<Map<String, dynamic>>> loadTransferTasks() async =>
      transferTasks.values.toList();

  Future<void> saveTransferTask(Map<String, dynamic> task) async {
    transferTasks[task['id'] as String] = task;
  }

  Future<void> updateTransferTask(Map<String, dynamic> task) async {
    transferTasks[task['id'] as String] = task;
  }

  Future<void> deleteTransferTask(String id) async {
    transferTasks.remove(id);
  }
}
