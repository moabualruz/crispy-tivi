import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_utils.dart';
import '../../profiles/presentation/providers/permission_guard.dart';
import '../domain/entities/recording.dart';
import 'dvr_service.dart';

/// Result of a schedule attempt.
enum ScheduleResult {
  /// Recording was scheduled successfully.
  scheduled,

  /// A conflict was detected — caller should
  /// show resolution UI.
  conflict,

  /// The current profile does not have permission
  /// to schedule recordings.
  permissionDenied,
}

/// DVR state.
class DvrState {
  const DvrState({this.recordings = const [], this.progressBytes = const {}});

  final List<Recording> recordings;

  /// Live progress for in-progress recordings:
  /// recordingId -> bytes written.
  final Map<String, int> progressBytes;

  List<Recording> get scheduled =>
      recordings.where((r) => r.status == RecordingStatus.scheduled).toList();

  List<Recording> get inProgress =>
      recordings.where((r) => r.status == RecordingStatus.recording).toList();

  List<Recording> get completed =>
      recordings.where((r) => r.status == RecordingStatus.completed).toList();

  int get totalStorageBytes => recordings
      .where((r) => r.fileSizeBytes != null)
      .fold(0, (sum, r) => sum + r.fileSizeBytes!);

  String get totalStorageMB => formatBytes(totalStorageBytes);

  DvrState copyWith({
    List<Recording>? recordings,
    Map<String, int>? progressBytes,
  }) {
    return DvrState(
      recordings: recordings ?? this.recordings,
      progressBytes: progressBytes ?? this.progressBytes,
    );
  }
}

/// Provider for recordings visible to the current user.
///
/// Filters based on DVR permissions:
/// - Admins and full DVR access: see all recordings
/// - View only: see shared recordings and own recordings
/// - None: see no recordings
final visibleRecordingsProvider = Provider<List<Recording>>((ref) {
  final dvrState = ref.watch(dvrServiceProvider).value;
  if (dvrState == null) return [];

  final permissionGuard = ref.read(permissionGuardProvider);

  return dvrState.recordings.where((rec) {
    return permissionGuard.canViewRecording(
      ownerProfileId: rec.ownerProfileId,
      isShared: rec.isShared,
    );
  }).toList();
});

/// Provider for scheduled recordings visible to
/// current user.
final visibleScheduledRecordingsProvider = Provider<List<Recording>>((ref) {
  final visible = ref.watch(visibleRecordingsProvider);
  return visible.where((r) => r.status == RecordingStatus.scheduled).toList();
});

/// Provider for completed recordings visible to
/// current user.
final visibleCompletedRecordingsProvider = Provider<List<Recording>>((ref) {
  final visible = ref.watch(visibleRecordingsProvider);
  return visible.where((r) => r.status == RecordingStatus.completed).toList();
});

/// Provider for in-progress recordings visible to
/// current user.
final visibleInProgressRecordingsProvider = Provider<List<Recording>>((ref) {
  final visible = ref.watch(visibleRecordingsProvider);
  return visible.where((r) => r.status == RecordingStatus.recording).toList();
});
