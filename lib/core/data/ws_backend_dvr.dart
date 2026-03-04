part of 'ws_backend.dart';

/// DVR/recording-related WebSocket commands.
mixin _WsDvrMixin on _WsBackendBase {
  // ── Recordings ───────────────────────────────────

  Future<List<Map<String, dynamic>>> loadRecordings() async {
    final data = await _send('loadRecordings');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveRecording(Map<String, dynamic> recording) =>
      _send('saveRecording', {'recording': recording});

  Future<void> updateRecording(Map<String, dynamic> recording) =>
      _send('updateRecording', {'recording': recording});
  Future<void> deleteRecording(String id) async {
    await _send('deleteRecording', {'id': id});
  }

  Future<String> getRecordingMarkers(String recordingId) async {
    final response = await _send('getRecordingMarkers', {
      'recordingId': recordingId,
    });
    // Over WebSocket, it's safer to return the stringified list directly or encode it depending on response format.
    // Ensure we just return it as a json string as that's what's expected.
    return jsonEncode(response);
  }

  // ── Storage Backends ─────────────────────────────

  Future<List<Map<String, dynamic>>> loadStorageBackends() async {
    final data = await _send('loadStorageBackends');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveStorageBackend(Map<String, dynamic> backend) =>
      _send('saveStorageBackend', {'backend': backend});

  Future<void> deleteStorageBackend(String id) =>
      _send('deleteStorageBackend', {'id': id});

  // ── Transfer Tasks ───────────────────────────────

  Future<List<Map<String, dynamic>>> loadTransferTasks() async {
    final data = await _send('loadTransferTasks');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveTransferTask(Map<String, dynamic> task) =>
      _send('saveTransferTask', {'task': task});

  Future<void> updateTransferTask(Map<String, dynamic> task) =>
      _send('updateTransferTask', {'task': task});

  Future<void> deleteTransferTask(String id) =>
      _send('deleteTransferTask', {'id': id});

  // ── DVR Algorithms ─────────────────────────────

  Future<String> expandRecurringRecordings(
    String recordingsJson,
    int nowUtcMs,
  ) async {
    final data = await _send('expandRecurringRecordings', {
      'recordingsJson': recordingsJson,
      'nowUtcMs': nowUtcMs,
    });
    return data as String;
  }

  Future<bool> detectRecordingConflict(
    String recordingsJson, {
    String? excludeId,
    required String channelName,
    required int startUtcMs,
    required int endUtcMs,
  }) async {
    final data = await _send('detectRecordingConflict', {
      'recordingsJson': recordingsJson,
      if (excludeId != null) 'excludeId': excludeId,
      'channelName': channelName,
      'startUtcMs': startUtcMs,
      'endUtcMs': endUtcMs,
    });
    return data as bool;
  }

  String sanitizeFilename(String name) {
    // Sync — local Dart fallback.
    return name.replaceAll(RegExp(r'[^\w\s-]'), '_');
  }

  // ── DVR: Recordings to Start ──────────────────

  Future<String> getRecordingsToStart(String recordingsJson, int nowMs) async {
    // Dart fallback — matches Rust logic.
    // Input expects: [{"id":..., "status":...,
    //   "startTime": epochMs, "endTime": epochMs}]
    List<dynamic> items;
    try {
      items = jsonDecode(recordingsJson) as List;
    } catch (_) {
      return '[]';
    }
    final ids =
        items
            .whereType<Map<String, dynamic>>()
            .where((r) {
              final status = r['status'] as String? ?? '';
              final start = r['startTime'] as int? ?? -1;
              final end = r['endTime'] as int? ?? 0;
              return status == 'scheduled' &&
                  start >= 0 &&
                  start <= nowMs &&
                  end > nowMs;
            })
            .map((r) => r['id'] as String)
            .toList();
    return jsonEncode(ids);
  }
}
