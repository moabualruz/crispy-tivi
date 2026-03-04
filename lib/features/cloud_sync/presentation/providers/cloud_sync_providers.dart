import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../settings/data/backup_service.dart';
import '../../data/cloud_sync_service.dart';
import '../../data/google_auth_service.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/sync_conflict.dart';

/// Settings key for auto-sync enabled state.
const String _autoSyncEnabledKey = 'crispy_tivi_auto_sync_enabled';

/// Provider for the Google authentication service.
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

/// Provider for the cloud sync service.
final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final backupService = ref.watch(backupServiceProvider);
  final authService = ref.watch(googleAuthServiceProvider);
  final backend = ref.read(crispyBackendProvider);

  final service = CloudSyncService(
    backupService: backupService,
    authService: authService,
    backend: backend,
  );

  ref.onDispose(() => service.dispose());
  return service;
});

/// Notifier for cloud sync state.
class CloudSyncNotifier extends Notifier<CloudSyncState> {
  @override
  CloudSyncState build() {
    // Initialize: restore session and auto-sync setting.
    _initialize();
    return const CloudSyncState();
  }

  GoogleAuthService get _authService => ref.read(googleAuthServiceProvider);

  CloudSyncService get _syncService => ref.read(cloudSyncServiceProvider);

  CacheService get _cacheService => ref.read(cacheServiceProvider);

  /// Initializes the notifier by loading settings and restoring session.
  Future<void> _initialize() async {
    // Load auto-sync setting from storage.
    await _loadAutoSyncSetting();

    // Try to restore session and auto-sync if enabled.
    await _tryRestoreSession();
  }

  /// Loads the auto-sync enabled setting from storage.
  Future<void> _loadAutoSyncSetting() async {
    try {
      final value = await _cacheService.getSetting(_autoSyncEnabledKey);
      final isEnabled = value == 'true';
      state = state.copyWith(isAutoSyncEnabled: isEnabled);
    } catch (e) {
      debugPrint('CloudSync: Failed to load auto-sync setting: $e');
    }
  }

  /// Attempts to restore previous sign-in session.
  Future<void> _tryRestoreSession() async {
    try {
      final user = await _authService.tryRestoreSession();
      if (user != null) {
        state = state.copyWith(
          status: SyncStatus.idle,
          userEmail: user.email,
          userDisplayName: user.displayName,
          userPhotoUrl: user.photoUrl,
        );

        // Trigger auto-sync if enabled.
        if (state.isAutoSyncEnabled) {
          debugPrint('CloudSync: Auto-sync triggered on app start');
          // Use syncIfNeeded which checks last sync time.
          final result = await _syncService.syncIfNeeded();
          if (result != null) {
            if (result.success) {
              state = state.copyWith(
                status: SyncStatus.success,
                lastSyncTime: DateTime.now().toUtc(),
              );
            }
            debugPrint('CloudSync: Auto-sync result: ${result.success}');
          }
        }
      }
    } catch (e) {
      debugPrint('CloudSync: Session restore failed: $e');
    }
  }

  /// Signs in with Google.
  Future<bool> signIn() async {
    try {
      state = state.copyWith(status: SyncStatus.syncing, clearError: true);

      final user = await _authService.signIn();
      if (user != null) {
        state = state.copyWith(
          status: SyncStatus.idle,
          userEmail: user.email,
          userDisplayName: user.displayName,
          userPhotoUrl: user.photoUrl,
        );
        return true;
      } else {
        state = state.copyWith(status: SyncStatus.notSignedIn);
        return false;
      }
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString());
      return false;
    }
  }

  /// Signs out from Google.
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      state = const CloudSyncState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Performs a sync operation.
  Future<SyncResult> syncNow({ConflictResolution? conflictResolution}) async {
    if (!state.isSignedIn) {
      return SyncResult.failure('Not signed in');
    }

    state = state.copyWith(status: SyncStatus.syncing, clearError: true);

    try {
      final result = await _syncService.syncNow(
        conflictResolution: conflictResolution,
      );

      if (result.success) {
        state = state.copyWith(
          status: SyncStatus.success,
          lastSyncTime: DateTime.now().toUtc(),
        );
      } else {
        state = state.copyWith(status: SyncStatus.error, error: result.error);
      }

      return result;
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString());
      return SyncResult.failure(e.toString());
    }
  }

  /// Forces upload of local data.
  Future<SyncResult> forceUpload() async {
    if (!state.isSignedIn) {
      return SyncResult.failure('Not signed in');
    }

    state = state.copyWith(status: SyncStatus.syncing, clearError: true);

    try {
      final result = await _syncService.forceUpload();

      if (result.success) {
        state = state.copyWith(
          status: SyncStatus.success,
          lastSyncTime: DateTime.now().toUtc(),
        );
      } else {
        state = state.copyWith(status: SyncStatus.error, error: result.error);
      }

      return result;
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString());
      return SyncResult.failure(e.toString());
    }
  }

  /// Forces download of cloud data.
  Future<SyncResult> forceDownload() async {
    if (!state.isSignedIn) {
      return SyncResult.failure('Not signed in');
    }

    state = state.copyWith(status: SyncStatus.syncing, clearError: true);

    try {
      final result = await _syncService.forceDownload();

      if (result.success) {
        state = state.copyWith(
          status: SyncStatus.success,
          lastSyncTime: DateTime.now().toUtc(),
        );
      } else {
        state = state.copyWith(status: SyncStatus.error, error: result.error);
      }

      return result;
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString());
      return SyncResult.failure(e.toString());
    }
  }

  /// Sets auto-sync enabled state.
  Future<void> setAutoSyncEnabled(bool enabled) async {
    state = state.copyWith(isAutoSyncEnabled: enabled);

    // Persist to storage.
    try {
      await _cacheService.setSetting(_autoSyncEnabledKey, enabled.toString());
    } catch (e) {
      debugPrint('CloudSync: Failed to save auto-sync setting: $e');
    }
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(clearError: true, status: SyncStatus.idle);
  }
}

/// Provider for cloud sync state.
final cloudSyncProvider = NotifierProvider<CloudSyncNotifier, CloudSyncState>(
  CloudSyncNotifier.new,
);

/// Provider for checking if signed in.
final isCloudSyncSignedInProvider = Provider<bool>((ref) {
  return ref.watch(cloudSyncProvider).isSignedIn;
});

/// Provider for last sync time.
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(cloudSyncProvider).lastSyncTime;
});

/// Provider for auto-sync enabled state.
final autoSyncEnabledProvider = Provider<bool>((ref) {
  return ref.watch(cloudSyncProvider).isAutoSyncEnabled;
});
