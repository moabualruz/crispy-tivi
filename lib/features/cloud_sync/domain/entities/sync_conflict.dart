/// Resolution strategy for sync conflicts.
enum ConflictResolution {
  /// Use local data (overwrite cloud).
  keepLocal,

  /// Use cloud data (overwrite local).
  keepCloud,

  /// Smart merge (combine data intelligently).
  merge,

  /// Cancel the sync operation.
  cancel,
}

/// Represents a sync conflict between local and cloud data.
class SyncConflict {
  const SyncConflict({
    required this.localModifiedTime,
    required this.cloudModifiedTime,
    this.localDeviceId,
    this.cloudDeviceId,
    this.localItemCount = 0,
    this.cloudItemCount = 0,
  });

  /// When local data was last modified.
  final DateTime localModifiedTime;

  /// When cloud data was last modified.
  final DateTime cloudModifiedTime;

  /// Device ID that modified local data.
  final String? localDeviceId;

  /// Device ID that modified cloud data.
  final String? cloudDeviceId;

  /// Number of items in local backup.
  final int localItemCount;

  /// Number of items in cloud backup.
  final int cloudItemCount;

  /// Time difference between local and cloud (positive = local is newer).
  Duration get timeDifference =>
      localModifiedTime.difference(cloudModifiedTime);

  /// Whether local data is newer.
  bool get isLocalNewer => timeDifference.inSeconds > 0;

  /// Whether cloud data is newer.
  bool get isCloudNewer => timeDifference.inSeconds < 0;

  /// Whether timestamps are close enough to be considered equal.
  bool get timestampsEqual => timeDifference.inSeconds.abs() <= 5;

  /// Whether this is a true conflict (both have changes).
  bool get isConflict => !timestampsEqual && localDeviceId != cloudDeviceId;

  /// Suggested resolution based on timestamps.
  ConflictResolution get suggestedResolution {
    if (timestampsEqual) {
      return ConflictResolution.cancel;
    }
    return isLocalNewer
        ? ConflictResolution.keepLocal
        : ConflictResolution.keepCloud;
  }
}

/// Error types that can occur during cloud sync.
sealed class CloudSyncError {
  const CloudSyncError(this.message);

  /// Human-readable error message.
  final String message;
}

/// Network-related error.
class NetworkSyncError extends CloudSyncError {
  const NetworkSyncError([super.message = 'No network connection']);
}

/// Authentication-related error.
class AuthSyncError extends CloudSyncError {
  const AuthSyncError([super.message = 'Authentication failed']);
}

/// Google Drive quota exceeded.
class QuotaExceededError extends CloudSyncError {
  const QuotaExceededError() : super('Google Drive storage quota exceeded');
}

/// Data corruption or parsing error.
class DataCorruptionError extends CloudSyncError {
  const DataCorruptionError(String details)
    : super('Data corruption: $details');
}

/// Rate limiting error.
class RateLimitError extends CloudSyncError {
  const RateLimitError([super.message = 'Too many requests, try again later']);
}

/// General sync error.
class GeneralSyncError extends CloudSyncError {
  const GeneralSyncError(super.message);
}
