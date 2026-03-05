part of 'ffi_backend.dart';

/// DVR/recording-related FFI calls.
mixin _FfiDvrMixin on _FfiBackendBase {
  // ── Recordings ───────────────────────────────────

  Future<List<Map<String, dynamic>>> loadRecordings() async {
    final json = await rust_api.loadRecordings();
    return _decodeJsonList(json);
  }

  Future<void> saveRecording(Map<String, dynamic> recording) =>
      rust_api.saveRecording(json: jsonEncode(recording));

  Future<void> updateRecording(Map<String, dynamic> recording) =>
      rust_api.updateRecording(json: jsonEncode(recording));
  Future<void> deleteRecording(String id) async {
    await rust_api.deleteRecording(id: id);
  }

  Future<String> getRecordingMarkers(String recordingId) async {
    return await rust_api.getRecordingMarkers(recordingId: recordingId);
  }

  // ── Storage Backends ─────────────────────────────

  Future<List<Map<String, dynamic>>> loadStorageBackends() async {
    final json = await rust_api.loadStorageBackends();
    return _decodeJsonList(json);
  }

  Future<void> saveStorageBackend(Map<String, dynamic> backend) =>
      rust_api.saveStorageBackend(json: jsonEncode(backend));

  Future<void> deleteStorageBackend(String id) =>
      rust_api.deleteStorageBackend(id: id);

  // ── Transfer Tasks ───────────────────────────────

  Future<List<Map<String, dynamic>>> loadTransferTasks() async {
    final json = await rust_api.loadTransferTasks();
    return _decodeJsonList(json);
  }

  Future<void> saveTransferTask(Map<String, dynamic> task) =>
      rust_api.saveTransferTask(json: jsonEncode(task));

  Future<void> updateTransferTask(Map<String, dynamic> task) =>
      rust_api.updateTransferTask(json: jsonEncode(task));

  Future<void> deleteTransferTask(String id) =>
      rust_api.deleteTransferTask(id: id);

  // ── DVR Algorithms ─────────────────────────────

  Future<String> expandRecurringRecordings(
    String recordingsJson,
    int nowUtcMs,
  ) => rust_api.expandRecurringRecordings(
    recordingsJson: recordingsJson,
    nowUtcMs: PlatformInt64Util.from(nowUtcMs),
  );

  Future<bool> detectRecordingConflict(
    String recordingsJson, {
    String? excludeId,
    required String channelName,
    required int startUtcMs,
    required int endUtcMs,
  }) => rust_api.detectRecordingConflict(
    recordingsJson: recordingsJson,
    excludeId: excludeId,
    channelName: channelName,
    startUtcMs: PlatformInt64Util.from(startUtcMs),
    endUtcMs: PlatformInt64Util.from(endUtcMs),
  );

  String sanitizeFilename(String name) => rust_api.sanitizeFilename(name: name);
}
