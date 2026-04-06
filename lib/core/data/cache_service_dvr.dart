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
    await _backend.saveRecording(recordingToMap(rec));
  }

  /// Update a recording's status and file info.
  Future<void> updateRecording(Recording rec) async {
    await _backend.updateRecording(recordingToMap(rec));
  }

  /// Delete a recording by ID.
  Future<void> deleteRecording(String id) async {
    await _backend.deleteRecording(id);
  }

  /// Get commercial markers for a given recording by ID.
  Future<List<CommercialMarker>> getRecordingMarkers(String recordingId) async {
    final jsonStr = await _backend.getRecordingMarkers(recordingId);
    final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
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
  // ── Algorithm Wrappers ───────────────────────────

  /// Filters DVR recordings by search query.
  Future<List<Map<String, dynamic>>> filterDvrRecordingsParsed(
    List<Recording> recordings,
    String query,
  ) async {
    final recordingsJson = jsonEncode(recordings.map(recordingToMap).toList());
    final resultJson = await _backend.filterDvrRecordings(
      recordingsJson,
      query,
    );
    return (jsonDecode(resultJson) as List).cast<Map<String, dynamic>>();
  }

  /// Computes storage breakdown for recordings.
  Future<Map<String, dynamic>> computeStorageBreakdownParsed(
    List<Recording> recordings,
    int nowMs,
  ) async {
    final recordingsJson = jsonEncode(recordings.map(recordingToMap).toList());
    final resultJson = await _backend.computeStorageBreakdown(
      recordingsJson,
      nowMs,
    );
    return jsonDecode(resultJson) as Map<String, dynamic>;
  }

  /// Sorts remote files via the Rust backend.
  ///
  /// Accepts pre-built maps (not domain entities) because
  /// [RemoteFile] is a presentation-layer type.
  Future<List<Map<String, dynamic>>> sortRemoteFilesParsed(
    List<Map<String, dynamic>> fileMaps,
    String orderStr,
  ) async {
    final filesJson = jsonEncode(fileMaps);
    final resultJson = await _backend.sortRemoteFiles(filesJson, orderStr);
    return (jsonDecode(resultJson) as List).cast<Map<String, dynamic>>();
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
    status: _parseRecordingStatus(m['status'] as String? ?? 'scheduled'),
    filePath: m['file_path'] as String?,
    fileSizeBytes: m['file_size_bytes'] as int?,
    isRecurring: m['is_recurring'] as bool? ?? false,
    recurDays: m['recur_days'] as int? ?? 0,
    profile: profile,
    ownerProfileId: m['owner_profile_id'] as String?,
    isShared: m['is_shared'] as bool? ?? true,
    remoteBackendId: m['remote_backend_id'] as String?,
    remotePath: m['remote_path'] as String?,
    autoDeletePolicy: _parseAutoDeletePolicy(
      m['auto_delete_policy'] as String?,
    ),
    keepEpisodeCount: m['keep_episode_count'] as int? ?? 5,
  );
}

AutoDeletePolicy _parseAutoDeletePolicy(String? name) {
  if (name == null) return AutoDeletePolicy.keepAll;
  return AutoDeletePolicy.values.firstWhere(
    (p) => p.name == name,
    orElse: () => AutoDeletePolicy.keepAll,
  );
}

StorageBackend _mapToStorageBackend(Map<String, dynamic> m) {
  final configRaw = m['config'] as Map<String, dynamic>? ?? {};
  final config = configRaw.map((k, v) => MapEntry(k, v.toString()));
  return StorageBackend(
    id: m['id'] as String,
    name: m['name'] as String,
    type: _storageTypeFromRust(m['type'] as String? ?? 'local'),
    config: config,
    isDefault: m['is_default'] as bool? ?? false,
  );
}

Map<String, dynamic> _storageBackendToMap(StorageBackend b) {
  return {
    'id': b.id,
    'name': b.name,
    'type': _storageTypeToRust(b.type),
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
    status: _transferStatusFromRust(m['status'] as String? ?? 'pending'),
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
    'status': _transferStatusToRust(t.status),
    'total_bytes': t.totalBytes,
    'transferred_bytes': t.transferredBytes,
    'created_at': _toNaiveDateTime(t.createdAt),
    'error_message': t.errorMessage,
    'remote_path': t.remotePath,
  };
}

// ── Serialization helpers ─────────────────────────────

/// Maps Dart [RecordingStatus] from a Rust string,
/// safe against unknown variants.
RecordingStatus _parseRecordingStatus(String s) => RecordingStatus.values
    .firstWhere((e) => e.name == s, orElse: () => RecordingStatus.scheduled);

/// Maps Dart [TransferStatus] to the Rust serialized string.
///
/// Rust variants: pending, inprogress, completed, failed, cancelled.
/// Dart extras: queued → pending, active → inprogress, paused → pending.
String _transferStatusToRust(TransferStatus s) => switch (s) {
  TransferStatus.queued => 'pending',
  TransferStatus.active => 'inprogress',
  TransferStatus.paused => 'pending',
  TransferStatus.completed => 'completed',
  TransferStatus.failed => 'failed',
  TransferStatus.cancelled => 'cancelled',
};

/// Maps a Rust transfer status string to Dart [TransferStatus].
TransferStatus _transferStatusFromRust(String s) => switch (s) {
  'pending' => TransferStatus.queued,
  'inprogress' => TransferStatus.active,
  'completed' => TransferStatus.completed,
  'failed' => TransferStatus.failed,
  'cancelled' => TransferStatus.cancelled,
  _ => TransferStatus.queued,
};

/// Maps Dart [StorageType] to the Rust BackendType string.
///
/// Rust variants: local, network_smb, network_nfs, cloud.
String _storageTypeToRust(StorageType t) => switch (t) {
  StorageType.local => 'local',
  StorageType.smb => 'network_smb',
  StorageType.s3 => 'cloud',
  StorageType.googleDrive => 'cloud',
  StorageType.ftp => 'cloud',
  StorageType.webdav => 'cloud',
};

/// Maps a Rust BackendType string to Dart [StorageType].
StorageType _storageTypeFromRust(String s) => switch (s) {
  'local' => StorageType.local,
  'network_smb' => StorageType.smb,
  'network_nfs' => StorageType.smb,
  'cloud' => StorageType.s3,
  _ => StorageType.local,
};
