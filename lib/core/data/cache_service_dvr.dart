part of 'cache_service.dart';

/// DVR recording, storage backend, and transfer task
/// methods for [CacheService].
mixin _CacheDvrMixin on _CacheServiceBase {
  // ── DVR Recordings ────────────────────────────────

  /// Load all recordings.
  Future<List<Recording>> loadRecordings() async {
    final maps = await _backend.loadRecordings();
    return maps.map(_mapToRecording).toList();
  }

  /// Save (insert or replace) a recording.
  Future<void> saveRecording(Recording rec) async {
    await _backend.saveRecording(_recordingToMap(rec));
  }

  /// Update a recording's status and file info.
  Future<void> updateRecording(Recording rec) async {
    await _backend.updateRecording(_recordingToMap(rec));
  }

  /// Delete a recording by ID.
  Future<void> deleteRecording(String id) async {
    await _backend.deleteRecording(id);
  }

  /// Get commercial markers for a given recording by ID.
  Future<List<CommercialMarker>> getRecordingMarkers(String recordingId) async {
    final jsonStr = await _backend.getRecordingMarkers(recordingId);
    final List<dynamic> list = jsonDecode(jsonStr);
    return list
        .map(
          (m) => CommercialMarker(
            startMs: m['startMs'] as int,
            endMs: m['endMs'] as int,
          ),
        )
        .toList();
  }

  // ── Storage Backends ──────────────────────────────

  /// Load all configured storage backends.
  Future<List<StorageBackend>> loadStorageBackends() async {
    final maps = await _backend.loadStorageBackends();
    return maps.map(_mapToStorageBackend).toList();
  }

  /// Save (insert or replace) a storage backend.
  Future<void> saveStorageBackend(StorageBackend backend) async {
    await _backend.saveStorageBackend(_storageBackendToMap(backend));
  }

  /// Delete a storage backend by ID.
  Future<void> deleteStorageBackend(String id) async {
    await _backend.deleteStorageBackend(id);
  }

  // ── Transfer Tasks ────────────────────────────────

  /// Load all transfer tasks.
  Future<List<TransferTask>> loadTransferTasks() async {
    final maps = await _backend.loadTransferTasks();
    return maps.map(_mapToTransferTask).toList();
  }

  /// Save (insert or replace) a transfer task.
  Future<void> saveTransferTask(TransferTask task) async {
    await _backend.saveTransferTask(_transferTaskToMap(task));
  }

  /// Update a transfer task's status and progress.
  Future<void> updateTransferTask(TransferTask task) async {
    await _backend.updateTransferTask(_transferTaskToMap(task));
  }

  /// Delete a transfer task by ID.
  Future<void> deleteTransferTask(String id) async {
    await _backend.deleteTransferTask(id);
  }
}

// ── DVR converters (top-level, private) ───────────

Recording _mapToRecording(Map<String, dynamic> m) {
  final profileName = m['profile'] as String?;
  final profile =
      profileName != null
          ? RecordingProfile.values.firstWhere(
            (p) => p.name == profileName,
            orElse: () => RecordingProfile.original,
          )
          : RecordingProfile.original;

  return Recording(
    id: m['id'] as String,
    channelId: m['channel_id'] as String?,
    channelName: m['channel_name'] as String,
    channelLogoUrl: m['channel_logo_url'] as String?,
    programName: m['program_name'] as String,
    streamUrl: m['stream_url'] as String?,
    startTime: _parseNaiveUtc(m['start_time'] as String),
    endTime: _parseNaiveUtc(m['end_time'] as String),
    status: RecordingStatus.values.byName(m['status'] as String),
    filePath: m['file_path'] as String?,
    fileSizeBytes: m['file_size_bytes'] as int?,
    isRecurring: m['is_recurring'] as bool? ?? false,
    recurDays: m['recur_days'] as int? ?? 0,
    profile: profile,
    ownerProfileId: m['owner_profile_id'] as String?,
    isShared: m['is_shared'] as bool? ?? true,
    remoteBackendId: m['remote_backend_id'] as String?,
    remotePath: m['remote_path'] as String?,
  );
}

Map<String, dynamic> _recordingToMap(Recording r) {
  return {
    'id': r.id,
    'channel_id': r.channelId,
    'channel_name': r.channelName,
    'channel_logo_url': r.channelLogoUrl,
    'program_name': r.programName,
    'stream_url': r.streamUrl,
    'start_time': _toNaiveDateTime(r.startTime),
    'end_time': _toNaiveDateTime(r.endTime),
    'status': r.status.name,
    'file_path': r.filePath,
    'file_size_bytes': r.fileSizeBytes,
    'is_recurring': r.isRecurring,
    'recur_days': r.recurDays,
    'profile': r.profile.name,
    'owner_profile_id': r.ownerProfileId,
    'is_shared': r.isShared,
    'remote_backend_id': r.remoteBackendId,
    'remote_path': r.remotePath,
  };
}

StorageBackend _mapToStorageBackend(Map<String, dynamic> m) {
  final configRaw = m['config'] as Map<String, dynamic>? ?? {};
  final config = configRaw.map((k, v) => MapEntry(k, v.toString()));
  return StorageBackend(
    id: m['id'] as String,
    name: m['name'] as String,
    type: StorageType.values.byName(m['type'] as String),
    config: config,
    isDefault: m['is_default'] as bool? ?? false,
  );
}

Map<String, dynamic> _storageBackendToMap(StorageBackend b) {
  return {
    'id': b.id,
    'name': b.name,
    'type': b.type.name,
    'config': b.config,
    'is_default': b.isDefault,
  };
}

TransferTask _mapToTransferTask(Map<String, dynamic> m) {
  return TransferTask(
    id: m['id'] as String,
    recordingId: m['recording_id'] as String,
    backendId: m['backend_id'] as String,
    direction: TransferDirection.values.byName(m['direction'] as String),
    status: TransferStatus.values.byName(m['status'] as String),
    totalBytes: m['total_bytes'] as int? ?? 0,
    transferredBytes: m['transferred_bytes'] as int? ?? 0,
    createdAt: _parseNaiveUtc(m['created_at'] as String),
    errorMessage: m['error_message'] as String?,
    remotePath: m['remote_path'] as String?,
  );
}

Map<String, dynamic> _transferTaskToMap(TransferTask t) {
  return {
    'id': t.id,
    'recording_id': t.recordingId,
    'backend_id': t.backendId,
    'direction': t.direction.name,
    'status': t.status.name,
    'total_bytes': t.totalBytes,
    'transferred_bytes': t.transferredBytes,
    'created_at': _toNaiveDateTime(t.createdAt),
    'error_message': t.errorMessage,
    'remote_path': t.remotePath,
  };
}
