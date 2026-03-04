/// Status of the cloud sync operation.
enum SyncStatus {
  /// Not signed in to Google.
  notSignedIn,

  /// Signed in but idle (no active sync).
  idle,

  /// Currently syncing.
  syncing,

  /// Sync completed successfully.
  success,

  /// Sync failed with an error.
  error,
}

/// Direction of sync operation.
enum SyncDirection {
  /// Local data is newer, upload to cloud.
  upload,

  /// Cloud data is newer, download to local.
  download,

  /// No changes detected.
  noChange,

  /// Conflict detected, requires resolution.
  conflict,
}

/// State of the cloud sync feature.
class CloudSyncState {
  const CloudSyncState({
    this.status = SyncStatus.notSignedIn,
    this.lastSyncTime,
    this.error,
    this.isAutoSyncEnabled = false,
    this.userEmail,
    this.userDisplayName,
    this.userPhotoUrl,
  });

  /// Current sync status.
  final SyncStatus status;

  /// Last successful sync timestamp.
  final DateTime? lastSyncTime;

  /// Error message if sync failed.
  final String? error;

  /// Whether auto-sync on app start is enabled.
  final bool isAutoSyncEnabled;

  /// Signed-in user's email.
  final String? userEmail;

  /// Signed-in user's display name.
  final String? userDisplayName;

  /// Signed-in user's profile photo URL.
  final String? userPhotoUrl;

  /// Whether user is signed in.
  bool get isSignedIn => userEmail != null;

  /// Whether sync is in progress.
  bool get isSyncing => status == SyncStatus.syncing;

  CloudSyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    String? error,
    bool? isAutoSyncEnabled,
    String? userEmail,
    String? userDisplayName,
    String? userPhotoUrl,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return CloudSyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      error: clearError ? null : (error ?? this.error),
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
      userEmail: clearUser ? null : (userEmail ?? this.userEmail),
      userDisplayName:
          clearUser ? null : (userDisplayName ?? this.userDisplayName),
      userPhotoUrl: clearUser ? null : (userPhotoUrl ?? this.userPhotoUrl),
    );
  }

  @override
  String toString() {
    return 'CloudSyncState(status: $status, '
        'lastSyncTime: $lastSyncTime, '
        'isAutoSyncEnabled: $isAutoSyncEnabled, '
        'userEmail: $userEmail)';
  }
}

/// Result of a sync operation.
class SyncResult {
  const SyncResult({
    required this.success,
    this.direction,
    this.error,
    this.itemsSynced = 0,
  });

  /// Whether sync completed successfully.
  final bool success;

  /// Direction of the sync operation performed.
  final SyncDirection? direction;

  /// Error message if sync failed.
  final String? error;

  /// Number of items synced.
  final int itemsSynced;

  /// Factory for a successful sync.
  factory SyncResult.success({
    required SyncDirection direction,
    int itemsSynced = 0,
  }) {
    return SyncResult(
      success: true,
      direction: direction,
      itemsSynced: itemsSynced,
    );
  }

  /// Factory for a failed sync.
  factory SyncResult.failure(String error) {
    return SyncResult(success: false, error: error);
  }

  /// Factory for no change.
  factory SyncResult.noChange() {
    return const SyncResult(success: true, direction: SyncDirection.noChange);
  }
}

/// Metadata about a cloud backup file.
class CloudBackupMetadata {
  const CloudBackupMetadata({
    required this.fileId,
    required this.modifiedTime,
    this.deviceId,
    this.syncVersion,
  });

  /// Google Drive file ID.
  final String fileId;

  /// Last modified timestamp.
  final DateTime modifiedTime;

  /// Device ID that last modified the file.
  final String? deviceId;

  /// Sync schema version.
  final int? syncVersion;
}
