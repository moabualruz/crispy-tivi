import 'package:meta/meta.dart';

/// Direction of a file transfer.
enum TransferDirection {
  /// Upload local recording to remote storage.
  upload,

  /// Download remote recording to local storage.
  download,
}

/// Status of a transfer task.
enum TransferStatus {
  /// Waiting in queue.
  queued,

  /// Currently transferring.
  active,

  /// User paused.
  paused,

  /// Transfer completed successfully.
  completed,

  /// Transfer failed (see [TransferTask.errorMessage]).
  failed,

  /// Transfer was cancelled.
  cancelled,
}

/// A file transfer task (upload or download).
@immutable
class TransferTask {
  const TransferTask({
    required this.id,
    this.recordingId,
    this.localPath,
    required this.backendId,
    required this.direction,
    required this.status,
    required this.createdAt,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.errorMessage,
    this.remotePath,
  });

  /// Unique task ID.
  final String id;

  /// Recording this transfer belongs to (optional).
  final String? recordingId;

  /// Local file path (used if recordingId is null).
  final String? localPath;

  /// Storage backend ID.
  final String backendId;

  /// Upload or download.
  final TransferDirection direction;

  /// Current status.
  final TransferStatus status;

  /// Total file size in bytes.
  final int totalBytes;

  /// Bytes transferred so far.
  final int transferredBytes;

  /// When the task was created.
  final DateTime createdAt;

  /// Error message if [status] is [TransferStatus.failed].
  final String? errorMessage;

  /// Remote file path on storage backend.
  final String? remotePath;

  /// Transfer progress (0.0 to 1.0).
  double get progress {
    if (totalBytes <= 0) return 0;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Whether the task is terminal (completed, failed, or cancelled).
  bool get isDone =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  TransferTask copyWith({
    String? id,
    String? recordingId,
    String? localPath,
    String? backendId,
    TransferDirection? direction,
    TransferStatus? status,
    int? totalBytes,
    int? transferredBytes,
    DateTime? createdAt,
    String? errorMessage,
    String? remotePath,
  }) {
    return TransferTask(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      localPath: localPath ?? this.localPath,
      backendId: backendId ?? this.backendId,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
      remotePath: remotePath ?? this.remotePath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferTask &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}
