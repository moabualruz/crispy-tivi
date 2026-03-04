import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/data/crispy_backend.dart';
import '../../settings/data/backup_service.dart';
import '../domain/entities/cloud_sync_state.dart';
import '../domain/entities/sync_conflict.dart';
import 'google_auth_service.dart';
import 'google_drive_api_client.dart';

/// Returns `true` when a sync should be performed.
///
/// A sync is needed when [force] is `true`, when [lastSync]
/// is `null` (never synced), or when more than
/// [intervalHours] have elapsed since [lastSync] relative
/// to [now].
bool needsSync({
  required bool force,
  DateTime? lastSync,
  required DateTime now,
  int intervalHours = 1,
}) =>
    force ||
    lastSync == null ||
    now.difference(lastSync).inHours >= intervalHours;

/// High-level cloud sync orchestration service.
///
/// Coordinates between [BackupService], [GoogleAuthService],
/// [CrispyBackend], and [GoogleDriveApiClient] to provide
/// seamless cloud sync.
class CloudSyncService {
  CloudSyncService({
    required BackupService backupService,
    required GoogleAuthService authService,
    required CrispyBackend backend,
  }) : _backupService = backupService,
       _authService = authService,
       _backend = backend;

  final BackupService _backupService;
  final GoogleAuthService _authService;
  final CrispyBackend _backend;
  GoogleDriveApiClient? _driveClient;

  /// Unique identifier for this device.
  String get deviceId => _getDeviceId();

  /// Whether currently connected to a network.
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Performs a sync operation.
  ///
  /// Determines sync direction automatically and handles conflicts.
  Future<SyncResult> syncNow({ConflictResolution? conflictResolution}) async {
    try {
      // Check prerequisites.
      if (!_authService.isSignedIn) {
        return SyncResult.failure('Not signed in');
      }

      if (!await isOnline) {
        return SyncResult.failure('No network connection');
      }

      // Get authenticated Drive client.
      final httpClient = await _authService.getAuthenticatedClient();
      if (httpClient == null) {
        return SyncResult.failure('Authentication failed');
      }

      _driveClient = GoogleDriveApiClient(httpClient);

      // Determine sync direction.
      final direction = await _determineSyncDirection();

      switch (direction) {
        case SyncDirection.upload:
          return await _uploadBackup();

        case SyncDirection.download:
          return await _downloadBackup();

        case SyncDirection.noChange:
          debugPrint('CloudSync: No changes detected');
          return SyncResult.noChange();

        case SyncDirection.conflict:
          if (conflictResolution != null) {
            return await _resolveConflict(conflictResolution);
          }
          // Return conflict for UI to handle.
          return SyncResult.failure('Sync conflict detected');
      }
    } catch (e) {
      debugPrint('CloudSync: Sync error: $e');
      if (e is CloudSyncError) {
        return SyncResult.failure(e.message);
      }
      return SyncResult.failure(e.toString());
    }
  }

  /// Forces upload of local data to cloud.
  Future<SyncResult> forceUpload() async {
    try {
      if (!_authService.isSignedIn) {
        return SyncResult.failure('Not signed in');
      }

      if (!await isOnline) {
        return SyncResult.failure('No network connection');
      }

      final httpClient = await _authService.getAuthenticatedClient();
      if (httpClient == null) {
        return SyncResult.failure('Authentication failed');
      }

      _driveClient = GoogleDriveApiClient(httpClient);
      return await _uploadBackup();
    } catch (e) {
      debugPrint('CloudSync: Force upload error: $e');
      if (e is CloudSyncError) {
        return SyncResult.failure(e.message);
      }
      return SyncResult.failure(e.toString());
    }
  }

  /// Forces download of cloud data to local.
  Future<SyncResult> forceDownload() async {
    try {
      if (!_authService.isSignedIn) {
        return SyncResult.failure('Not signed in');
      }

      if (!await isOnline) {
        return SyncResult.failure('No network connection');
      }

      final httpClient = await _authService.getAuthenticatedClient();
      if (httpClient == null) {
        return SyncResult.failure('Authentication failed');
      }

      _driveClient = GoogleDriveApiClient(httpClient);
      return await _downloadBackup();
    } catch (e) {
      debugPrint('CloudSync: Force download error: $e');
      if (e is CloudSyncError) {
        return SyncResult.failure(e.message);
      }
      return SyncResult.failure(e.toString());
    }
  }

  /// Checks if a sync is needed and performs it if auto-sync is enabled.
  Future<SyncResult?> syncIfNeeded({bool force = false}) async {
    if (!_authService.isSignedIn) return null;
    if (!await isOnline) return null;

    // Check if we need to sync (e.g., based on last sync time).
    final lastSync = await _getLastSyncTime();
    final now = DateTime.now().toUtc();

    // Sync if never synced or more than 1 hour since last sync.
    if (needsSync(force: force, lastSync: lastSync, now: now)) {
      return await syncNow();
    }

    return null;
  }

  /// Gets conflict details for UI display.
  Future<SyncConflict?> getConflictDetails() async {
    try {
      if (_driveClient == null) {
        final httpClient = await _authService.getAuthenticatedClient();
        if (httpClient == null) return null;
        _driveClient = GoogleDriveApiClient(httpClient);
      }

      final cloudMetadata = await _driveClient!.getBackupMetadata();
      if (cloudMetadata == null) return null;

      final localModified = await _getLocalModifiedTime();
      if (localModified == null) return null;

      return SyncConflict(
        localModifiedTime: localModified,
        cloudModifiedTime: cloudMetadata.modifiedTime,
        localDeviceId: deviceId,
        cloudDeviceId: cloudMetadata.deviceId,
      );
    } catch (e) {
      debugPrint('CloudSync: Error getting conflict details: $e');
      return null;
    }
  }

  /// Determines the sync direction based on modification times.
  Future<SyncDirection> _determineSyncDirection() async {
    final cloudMetadata = await _driveClient!.getBackupMetadata();
    final localModified = await _getLocalModifiedTime();
    final lastSync = await _getLastSyncTime();

    final result = _backend.determineSyncDirection(
      localModified?.millisecondsSinceEpoch ?? 0,
      cloudMetadata?.modifiedTime.millisecondsSinceEpoch ?? 0,
      lastSync?.millisecondsSinceEpoch ?? 0,
      deviceId,
      cloudMetadata?.deviceId ?? '',
    );

    return switch (result) {
      'upload' => SyncDirection.upload,
      'download' => SyncDirection.download,
      'conflict' => SyncDirection.conflict,
      _ => SyncDirection.noChange,
    };
  }

  /// Uploads local backup to cloud.
  Future<SyncResult> _uploadBackup() async {
    debugPrint('CloudSync: Uploading backup...');

    // Export backup with device ID.
    final backup = await _backupService.exportBackup();
    final backupMap = json.decode(backup) as Map<String, dynamic>;
    backupMap['deviceId'] = deviceId;
    backupMap['syncVersion'] = 2;
    final enrichedBackup = json.encode(backupMap);

    // Upload to Drive.
    await _driveClient!.uploadBackup(enrichedBackup);

    // Update local sync metadata.
    final now = DateTime.now().toUtc();
    await _setLastSyncTime(now);
    await _setLocalModifiedTime(now);

    debugPrint('CloudSync: Upload complete');
    return SyncResult.success(direction: SyncDirection.upload);
  }

  /// Downloads cloud backup to local.
  Future<SyncResult> _downloadBackup() async {
    debugPrint('CloudSync: Downloading backup...');

    final content = await _driveClient!.downloadBackup();
    if (content == null) {
      return SyncResult.failure('No backup found in cloud');
    }

    // Import the backup.
    final summary = await _backupService.importBackup(content);
    debugPrint('CloudSync: Imported: $summary');

    // Update local sync metadata.
    final now = DateTime.now().toUtc();
    await _setLastSyncTime(now);
    await _setLocalModifiedTime(now);

    debugPrint('CloudSync: Download complete');
    return SyncResult.success(
      direction: SyncDirection.download,
      itemsSynced: summary.total,
    );
  }

  /// Resolves a conflict using the specified resolution.
  Future<SyncResult> _resolveConflict(ConflictResolution resolution) async {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return await _uploadBackup();

      case ConflictResolution.keepCloud:
        return await _downloadBackup();

      case ConflictResolution.merge:
        return await _smartMerge();

      case ConflictResolution.cancel:
        return SyncResult.failure('Sync cancelled');
    }
  }

  /// Gets the last sync timestamp.
  Future<DateTime?> _getLastSyncTime() async {
    return _backupService.getLastSyncTime();
  }

  /// Sets the last sync timestamp.
  Future<void> _setLastSyncTime(DateTime time) async {
    await _backupService.setLastSyncTime(time);
  }

  /// Gets the local modification timestamp.
  Future<DateTime?> _getLocalModifiedTime() async {
    return _backupService.getLocalModifiedTime();
  }

  /// Sets the local modification timestamp.
  Future<void> _setLocalModifiedTime(DateTime time) async {
    await _backupService.setLocalModifiedTime(time);
  }

  String? _cachedDeviceId;

  /// Gets a unique device identifier.
  ///
  /// Cached so every call in the same session returns the
  /// same value — critical for sync direction detection.
  String _getDeviceId() {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    String id;
    if (kIsWeb) {
      id = 'web_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      try {
        id =
            '${Platform.operatingSystem}_'
            '${Platform.localHostname}_'
            '${Platform.operatingSystemVersion.hashCode}';
      } catch (_) {
        id = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
    }
    _cachedDeviceId = id;
    return id;
  }

  /// Performs a smart merge of local and cloud data.
  ///
  /// Delegates the actual merge logic to [CrispyBackend]
  /// which runs the merge algorithm in Rust.
  Future<SyncResult> _smartMerge() async {
    debugPrint('CloudSync: Starting smart merge...');

    // 1. Export local backup as JSON string.
    final localJson = await _backupService.exportBackup();

    // 2. Download cloud backup as JSON string.
    final cloudJson = await _driveClient!.downloadBackup();
    if (cloudJson == null) {
      // No cloud data — just upload local.
      return await _uploadBackup();
    }

    // 3. Merge via Rust backend.
    final mergedJson = await _backend.mergeCloudBackups(
      localJson,
      cloudJson,
      deviceId,
    );

    // 4. Import the merged result locally.
    final summary = await _backupService.importBackup(mergedJson);
    debugPrint('CloudSync: Merged import: $summary');

    // 5. Upload the merged result to cloud.
    final merged = json.decode(mergedJson) as Map<String, dynamic>;
    merged['deviceId'] = deviceId;
    merged['syncVersion'] = 2;
    await _driveClient!.uploadBackup(
      const JsonEncoder.withIndent('  ').convert(merged),
    );

    // 6. Update sync metadata.
    final now = DateTime.now().toUtc();
    await _setLastSyncTime(now);
    await _setLocalModifiedTime(now);

    debugPrint('CloudSync: Smart merge complete');
    return SyncResult.success(
      direction: SyncDirection.upload,
      itemsSynced: summary.total,
    );
  }

  /// Disposes of resources.
  void dispose() {
    _driveClient?.dispose();
  }
}
