import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_directories.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../domain/entities/recording.dart';
import 'dvr_state.dart';
import 'recording_engine.dart';
import 'transfer_service.dart';

/// Handles stream capture lifecycle for DVR recordings.
///
/// Extracted from [DvrService] to keep file sizes manageable.
/// Requires access to the notifier's [state] via a getter,
/// and a [setState] callback to push new state.
class DvrCaptureHelper {
  DvrCaptureHelper({
    required this.engine,
    required this.cache,
    required this.backend,
    required this.ref,
    required this.getState,
    required this.setState,
    required this.onFail,
  });

  final RecordingEngine engine;
  final CacheService cache;
  final CrispyBackend backend;
  final Ref ref;
  final DvrState? Function() getState;
  final void Function(AsyncData<DvrState>) setState;
  final Future<void> Function(String id) onFail;

  /// Begins HTTP stream capture for a recording.
  void captureStream(Recording rec) {
    _getRecordingDir().then((dir) {
      final sanitized = backend
          .sanitizeFilename(rec.programName)
          .replaceAll(RegExp(r'\s+'), '_');
      final ext = rec.profile.container.extension;
      final filePath = '$dir/${sanitized}_${rec.id}$ext';

      debugPrint(
        'DvrService: capturing '
        '"${rec.programName}" with profile '
        '${rec.profile.label} to $filePath',
      );

      engine
          .startCapture(
            recordingId: rec.id,
            streamUrl: rec.streamUrl!,
            outputPath: filePath,
          )
          .listen(
            (bytes) {
              _updateProgress(rec.id, bytes);
            },
            onDone: () {
              _completeCapture(rec.id, filePath);
            },
            onError: (Object error) {
              onFail(rec.id);
            },
          );
    });
  }

  void _updateProgress(String id, int bytes) {
    final current = getState();
    if (current != null) {
      final newProgress = Map<String, int>.from(current.progressBytes);
      newProgress[id] = bytes;
      setState(AsyncData(current.copyWith(progressBytes: newProgress)));
    }
  }

  Future<void> _completeCapture(String id, String filePath) async {
    final current = getState();
    if (current == null) return;

    // Get final bytes from progress and clean up.
    final newProgress = Map<String, int>.from(current.progressBytes);
    final finalBytes = newProgress.remove(id) ?? 0;

    final updated =
        current.recordings.map((r) {
          if (r.id != id) return r;
          return r.copyWith(
            status: RecordingStatus.completed,
            filePath: filePath,
            fileSizeBytes: finalBytes,
          );
        }).toList();

    final rec = updated.firstWhereOrNull((r) => r.id == id);
    if (rec == null) return;
    await cache.updateRecording(rec);
    setState(
      AsyncData(DvrState(recordings: updated, progressBytes: newProgress)),
    );

    // Auto-upload to default cloud backend.
    _autoUploadIfConfigured(id);
  }

  /// Queues auto-upload to the default storage backend.
  void _autoUploadIfConfigured(String recordingId) {
    try {
      final transferState = ref.read(transferServiceProvider).value;
      final defaultBackend = transferState?.defaultBackend;

      if (defaultBackend != null) {
        debugPrint(
          'DvrService: auto-uploading to '
          '${defaultBackend.name}',
        );
        ref
            .read(transferServiceProvider.notifier)
            .queueUpload(recordingId, defaultBackend.id);
      }
    } catch (e) {
      debugPrint('DvrService: auto-upload skipped: $e');
    }
  }

  /// Stops a recording early and completes it.
  Future<void> stopAndComplete(String id) async {
    engine.stopCapture(id);

    final current = getState();
    if (current == null) return;

    final rec = current.recordings.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('Recording not found: $id'),
    );

    if (rec.status != RecordingStatus.recording) {
      return;
    }

    // Get final bytes from progress.
    final newProgress = Map<String, int>.from(current.progressBytes);
    final finalBytes = newProgress.remove(id) ?? 0;

    // Compute file path.
    final dir = await _getRecordingDir();
    final sanitized = backend
        .sanitizeFilename(rec.programName)
        .replaceAll(RegExp(r'\s+'), '_');
    final ext = rec.profile.container.extension;
    final filePath = '$dir/${sanitized}_${rec.id}$ext';

    final updated =
        current.recordings.map((r) {
          if (r.id != id) return r;
          return r.copyWith(
            status: RecordingStatus.completed,
            filePath: filePath,
            fileSizeBytes: finalBytes,
          );
        }).toList();

    final updatedRec = updated.firstWhereOrNull((r) => r.id == id);
    if (updatedRec == null) return;
    await cache.updateRecording(updatedRec);
    setState(
      AsyncData(DvrState(recordings: updated, progressBytes: newProgress)),
    );
  }

  Future<String> _getRecordingDir() async {
    if (kIsWeb) return '/tmp';
    return AppDirectories.recordings;
  }
}
