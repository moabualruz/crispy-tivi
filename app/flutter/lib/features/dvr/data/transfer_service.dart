import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../cloud_sync/presentation/providers/cloud_sync_providers.dart';
import '../domain/entities/storage_backend.dart';
import '../domain/entities/transfer_task.dart';
import '../domain/storage_provider.dart';
import 'providers/storage_provider_factory.dart';

/// State for the transfer service.
class TransferState {
  const TransferState({this.tasks = const [], this.backends = const []});

  /// All transfer tasks (active, queued, completed).
  final List<TransferTask> tasks;

  /// Configured storage backends.
  final List<StorageBackend> backends;

  List<TransferTask> get queued =>
      tasks.where((t) => t.status == TransferStatus.queued).toList();

  List<TransferTask> get active =>
      tasks.where((t) => t.status == TransferStatus.active).toList();

  List<TransferTask> get completed =>
      tasks.where((t) => t.status == TransferStatus.completed).toList();

  List<TransferTask> get failed =>
      tasks.where((t) => t.status == TransferStatus.failed).toList();

  /// Default upload backend, if any.
  StorageBackend? get defaultBackend =>
      backends.where((b) => b.isDefault).firstOrNull;

  TransferState copyWith({
    List<TransferTask>? tasks,
    List<StorageBackend>? backends,
  }) {
    return TransferState(
      tasks: tasks ?? this.tasks,
      backends: backends ?? this.backends,
    );
  }
}

/// Manages file transfers between local and remote
/// storage backends.
///
/// Processes one transfer at a time (sequential queue).
/// Persists tasks to DB so they survive app restarts.
class TransferService extends AsyncNotifier<TransferState> {
  late CacheService _cache;
  StorageProviderFactory? _factory;
  StorageProvider? _activeProvider;
  bool _processing = false;
  static int _idCounter = 0;

  @override
  Future<TransferState> build() async {
    _cache = ref.read(cacheServiceProvider);
    _factory = StorageProviderFactory(
      googleAuthService: ref.read(googleAuthServiceProvider),
      backend: ref.read(crispyBackendProvider),
    );

    final tasks = await _cache.loadTransferTasks();
    final backends = await _cache.loadStorageBackends();

    ref.onDispose(() {
      _activeProvider?.dispose();
    });

    // Resume any queued transfers.
    Future.microtask(_processQueue);

    return TransferState(tasks: tasks, backends: backends);
  }

  // ── Storage Backend Management ──────────────────────

  /// Adds or updates a storage backend.
  Future<void> saveBackend(StorageBackend backend) async {
    await _cache.saveStorageBackend(backend);
    final backends = await _cache.loadStorageBackends();
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(backends: backends));
    }
  }

  /// Removes a storage backend.
  Future<void> deleteBackend(String id) async {
    await _cache.deleteStorageBackend(id);
    final backends = await _cache.loadStorageBackends();
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(backends: backends));
    }
  }

  /// Sets a backend as the default upload target.
  Future<void> setDefaultBackend(String id) async {
    final backends = state.value?.backends ?? [];

    // Clear previous default, set new one.
    for (final b in backends) {
      final updated = b.copyWith(isDefault: b.id == id);
      await _cache.saveStorageBackend(updated);
    }

    final refreshed = await _cache.loadStorageBackends();
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(backends: refreshed));
    }
  }

  /// Lists files at [path] on the given [backend].
  ///
  /// Returns an empty list if the factory is not yet ready
  /// or if the provider throws.
  Future<List<RemoteFile>> listFiles(
    StorageBackend backend,
    String path,
  ) async {
    if (_factory == null) return [];
    final provider = await _factory!.create(backend);
    try {
      return await provider.listFiles(path);
    } catch (e) {
      debugPrint('TransferService: listFiles failed: $e');
      rethrow;
    } finally {
      await provider.dispose();
    }
  }

  /// Tests connection to a storage backend.
  Future<bool> testConnection(StorageBackend backend) async {
    if (_factory == null) return false;
    try {
      final provider = await _factory!.create(backend);
      final ok = await provider.testConnection();
      await provider.dispose();
      return ok;
    } catch (e) {
      debugPrint('TransferService: test failed: $e');
      return false;
    }
  }

  // ── Transfer Queue ──────────────────────────────────

  /// Queues an upload for a recording.
  Future<void> queueUpload(String recordingId, String backendId) async {
    final task = TransferTask(
      id:
          'tx_${DateTime.now().millisecondsSinceEpoch}'
          '_${_idCounter++}',
      recordingId: recordingId,
      backendId: backendId,
      direction: TransferDirection.upload,
      status: TransferStatus.queued,
      createdAt: DateTime.now(),
    );

    await _cache.saveTransferTask(task);
    _addTask(task);
    _processQueue();
  }

  /// Queues an upload for a local file path.
  Future<void> queueLocalUpload(
    String localPath,
    String backendId, {
    String? remotePath,
  }) async {
    final task = TransferTask(
      id:
          'tx_${DateTime.now().millisecondsSinceEpoch}'
          '_${_idCounter++}',
      localPath: localPath,
      backendId: backendId,
      direction: TransferDirection.upload,
      status: TransferStatus.queued,
      createdAt: DateTime.now(),
      remotePath: remotePath,
    );

    await _cache.saveTransferTask(task);
    _addTask(task);
    _processQueue();
  }

  /// Queues a download for a recording.
  Future<void> queueDownload(
    String recordingId,
    String backendId, {
    String? remotePath,
  }) async {
    final task = TransferTask(
      id:
          'tx_${DateTime.now().millisecondsSinceEpoch}'
          '_${_idCounter++}',
      recordingId: recordingId,
      backendId: backendId,
      direction: TransferDirection.download,
      status: TransferStatus.queued,
      createdAt: DateTime.now(),
      remotePath: remotePath,
    );

    await _cache.saveTransferTask(task);
    _addTask(task);
    _processQueue();
  }

  /// Pauses an active or queued transfer.
  Future<void> pauseTransfer(String taskId) async {
    await _updateTaskStatus(taskId, TransferStatus.paused);
  }

  /// Resumes a paused transfer.
  Future<void> resumeTransfer(String taskId) async {
    await _updateTaskStatus(taskId, TransferStatus.queued);
    _processQueue();
  }

  /// Cancels and removes a transfer.
  Future<void> cancelTransfer(String taskId) async {
    await _cache.deleteTransferTask(taskId);
    _removeTask(taskId);
  }

  // ── Queue Processor ─────────────────────────────────

  Future<void> _processQueue() async {
    if (_processing || _factory == null) return;
    _processing = true;

    try {
      while (true) {
        final current = state.value;
        if (current == null) break;

        final next =
            current.tasks
                .where((t) => t.status == TransferStatus.queued)
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        if (next.isEmpty) break;

        await _executeTransfer(next.first);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _executeTransfer(TransferTask task) async {
    final backends = state.value?.backends ?? [];
    final backend = backends.where((b) => b.id == task.backendId).firstOrNull;

    if (backend == null) {
      await _failTask(task.id, 'Storage backend not found');
      return;
    }

    // Mark active.
    await _updateTaskStatus(task.id, TransferStatus.active);

    try {
      _activeProvider = await _factory!.create(backend);

      if (task.direction == TransferDirection.upload) {
        await _executeUpload(task);
      } else {
        await _executeDownload(task);
      }

      await _activeProvider?.dispose();
      _activeProvider = null;

      // Mark completed.
      await _updateTaskStatus(task.id, TransferStatus.completed);
    } catch (e) {
      await _activeProvider?.dispose();
      _activeProvider = null;

      debugPrint('TransferService: transfer failed: $e');
      await _failTask(task.id, e.toString());
    }
  }

  Future<void> _executeUpload(TransferTask task) async {
    if (_activeProvider == null || kIsWeb) return;

    String? filePath;
    String fileId;

    if (task.localPath != null) {
      filePath = task.localPath;
      fileId = task.id;
    } else {
      // Find the recording's local file path.
      final recordings = await _cache.loadRecordings();
      final rec = recordings.where((r) => r.id == task.recordingId).firstOrNull;

      if (rec?.filePath == null) {
        throw StateError('Recording file not found');
      }
      filePath = rec!.filePath;
      fileId = rec.id;
    }

    final localFile = File(filePath!);
    if (!await localFile.exists()) {
      throw FileSystemException('Local file missing', filePath);
    }

    final fileSize = await localFile.length();
    final remotePath = task.remotePath ?? '$fileId.ts';

    // Update total bytes.
    _updateTask(task.copyWith(totalBytes: fileSize, remotePath: remotePath));

    await _activeProvider!.upload(filePath, remotePath, (sent, total) {
      _updateTask(task.copyWith(transferredBytes: sent, totalBytes: total));
    });

    if (task.recordingId != null) {
      // Update recording with remote info.
      final backends = state.value?.backends ?? [];
      final backend = backends.where((b) => b.id == task.backendId).firstOrNull;
      if (backend != null) {
        final recordings = await _cache.loadRecordings();
        final rec =
            recordings.where((r) => r.id == task.recordingId).firstOrNull;
        if (rec != null) {
          final updated = rec.copyWith(
            remoteBackendId: backend.id,
            remotePath: remotePath,
          );
          await _cache.updateRecording(updated);
        }
      }
    }
  }

  Future<void> _executeDownload(TransferTask task) async {
    if (_activeProvider == null || kIsWeb) return;

    final remotePath = task.remotePath;
    if (remotePath == null || remotePath.isEmpty) {
      throw StateError('No remote path for download');
    }

    // Determine local download path.
    final recordings = await _cache.loadRecordings();
    final rec = recordings.where((r) => r.id == task.recordingId).firstOrNull;

    final localPath = rec?.filePath ?? '/tmp/${task.recordingId}.ts';

    await _activeProvider!.download(remotePath, localPath, (received, total) {
      _updateTask(task.copyWith(transferredBytes: received, totalBytes: total));
    });
  }

  // ── State helpers ───────────────────────────────────

  void _addTask(TransferTask task) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(tasks: [...current.tasks, task]));
  }

  void _removeTask(String taskId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        tasks: current.tasks.where((t) => t.id != taskId).toList(),
      ),
    );
  }

  void _updateTask(TransferTask updated) {
    final current = state.value;
    if (current == null) return;

    final tasks =
        current.tasks.map((t) {
          return t.id == updated.id ? updated : t;
        }).toList();

    state = AsyncData(current.copyWith(tasks: tasks));
  }

  Future<void> _updateTaskStatus(String taskId, TransferStatus status) async {
    final current = state.value;
    if (current == null) return;

    final tasks =
        current.tasks.map((t) {
          if (t.id != taskId) return t;
          return t.copyWith(status: status);
        }).toList();

    state = AsyncData(current.copyWith(tasks: tasks));

    // Persist to DB.
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      await _cache.updateTransferTask(task);
    }
  }

  Future<void> _failTask(String taskId, String error) async {
    final current = state.value;
    if (current == null) return;

    final tasks =
        current.tasks.map((t) {
          if (t.id != taskId) return t;
          return t.copyWith(status: TransferStatus.failed, errorMessage: error);
        }).toList();

    state = AsyncData(current.copyWith(tasks: tasks));

    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      await _cache.updateTransferTask(task);
    }
  }
}

/// Provider for the transfer service.
final transferServiceProvider =
    AsyncNotifierProvider<TransferService, TransferState>(TransferService.new);

/// Provider for configured storage backends (convenience).
final storageBackendsProvider = Provider<List<StorageBackend>>((ref) {
  final state = ref.watch(transferServiceProvider).value;
  return state?.backends ?? [];
});
