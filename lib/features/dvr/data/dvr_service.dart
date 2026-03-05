import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../../core/data/data_change_event.dart';
import '../../../core/data/event_bus_provider.dart';
import '../../player/presentation/providers/player_providers.dart';
import '../../profiles/data/profile_service.dart';
import '../../profiles/domain/permission_guard.dart';
import '../domain/entities/recording.dart';
import '../domain/entities/recording_profile.dart';
import 'dvr_capture_helper.dart';
import 'dvr_state.dart';
import 'recording_engine.dart';
import 'transfer_service.dart';
import '../domain/utils/dvr_payload.dart';

export 'dvr_state.dart';

/// Manages DVR recording state — scheduling, status tracking,
/// stream capture, and storage monitoring.
///
/// Persists all recordings to Drift (SQLite) and uses
/// [RecordingEngine] for actual stream capture on native
/// platforms (no-op on web).
class DvrService extends AsyncNotifier<DvrState> {
  late CacheService _cache;
  late CrispyBackend _backend;
  late RecordingEngine _engine;
  late DvrCaptureHelper _capture;
  Timer? _schedulerTimer;
  static int _idCounter = 0;

  /// Default recording profile for new recordings.
  RecordingProfile _defaultProfile = RecordingProfile.original;

  /// Gets the current default recording profile.
  RecordingProfile get defaultProfile => _defaultProfile;

  /// Sets the default recording profile.
  void setDefaultProfile(RecordingProfile profile) {
    _defaultProfile = profile;
    debugPrint(
      'DvrService: default profile set to '
      '${profile.label}',
    );
  }

  @override
  Future<DvrState> build() async {
    _cache = ref.read(cacheServiceProvider);
    _backend = ref.read(crispyBackendProvider);
    _engine = RecordingEngine();
    _capture = DvrCaptureHelper(
      engine: _engine,
      cache: _cache,
      backend: _backend,
      ref: ref,
      getState: () => state.value,
      setState: (s) => state = s,
      onFail: failRecording,
    );

    final recordings = await _cache.loadRecordings();

    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkScheduledRecordings();
      _expandRecurringRecordings();
    });

    // Event-driven re-check: trigger immediately when a recording or
    // reminder changes, without waiting for the next 30-second tick.
    ref.listen<AsyncValue<DataChangeEvent>>(eventBusProvider, (_, next) {
      next.whenData((event) {
        if (event is RecordingChanged || event is ReminderChanged) {
          _checkScheduledRecordings();
        }
      });
    });

    ref.onDispose(() {
      _schedulerTimer?.cancel();
      _engine.stopAll();
    });

    return DvrState(recordings: recordings);
  }

  /// Schedules a new recording.
  ///
  /// Returns [ScheduleResult.permissionDenied] if the current profile
  /// lacks the DVR scheduling permission.
  /// Returns [ScheduleResult.conflict] if the time slot overlaps
  /// with an existing scheduled recording on the **same** channel.
  ///
  /// If [profile] is not specified, uses the default profile.
  /// The current profile becomes the owner of the recording.
  Future<ScheduleResult> scheduleRecording({
    required String channelName,
    required String programName,
    required DateTime startTime,
    required DateTime endTime,
    String? channelId,
    String? channelLogoUrl,
    String? streamUrl,
    bool isRecurring = false,
    int recurDays = 0,
    RecordingProfile? profile,
    bool isShared = true,
  }) async {
    // Check permission
    final permissionGuard = ref.read(permissionGuardProvider);
    if (!permissionGuard.canScheduleRecordings) {
      debugPrint('DvrService: permission denied for scheduling');
      return ScheduleResult.permissionDenied;
    }

    final current = state.value?.recordings ?? [];

    // Delegate conflict detection to Rust backend.
    final recordingsJson = jsonEncode(
      current
          .where((r) => r.status == RecordingStatus.scheduled)
          .map(recordingToMap)
          .toList(),
    );
    final conflict = await _backend.detectRecordingConflict(
      recordingsJson,
      channelName: channelName,
      startUtcMs: startTime.millisecondsSinceEpoch,
      endUtcMs: endTime.millisecondsSinceEpoch,
    );

    if (conflict) {
      return ScheduleResult.conflict;
    }

    // Get current profile as owner
    final profileState = ref.read(profileServiceProvider).value;
    final ownerProfileId = profileState?.activeProfileId;

    await _addRecording(
      channelName: channelName,
      programName: programName,
      startTime: startTime,
      endTime: endTime,
      channelId: channelId,
      channelLogoUrl: channelLogoUrl,
      streamUrl: streamUrl,
      isRecurring: isRecurring,
      recurDays: recurDays,
      profile: profile ?? _defaultProfile,
      ownerProfileId: ownerProfileId,
      isShared: isShared,
    );
    return ScheduleResult.scheduled;
  }

  /// Returns all currently-scheduled recordings that overlap with
  /// the given [startTime]–[endTime] window.
  ///
  /// Two recordings overlap when `start < otherEnd && end > otherStart`.
  /// This is a pure-Dart computation on the in-memory state — no
  /// Rust round-trip required.
  List<Recording> getConflictingRecordings({
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final scheduled =
        (state.value?.recordings ?? [])
            .where((r) => r.status == RecordingStatus.scheduled)
            .toList();

    return scheduled
        .where(
          (r) => startTime.isBefore(r.endTime) && endTime.isAfter(r.startTime),
        )
        .toList();
  }

  /// Force-schedules a recording, ignoring conflicts.
  ///
  /// If [profile] is not specified, uses the default profile.
  /// Returns false if permission denied.
  Future<bool> forceScheduleRecording({
    required String channelName,
    required String programName,
    required DateTime startTime,
    required DateTime endTime,
    String? channelId,
    String? channelLogoUrl,
    String? streamUrl,
    bool isRecurring = false,
    int recurDays = 0,
    RecordingProfile? profile,
    bool isShared = true,
  }) async {
    // Check permission
    final permissionGuard = ref.read(permissionGuardProvider);
    if (!permissionGuard.canScheduleRecordings) {
      debugPrint('DvrService: permission denied for scheduling');
      return false;
    }

    // Get current profile as owner
    final profileState = ref.read(profileServiceProvider).value;
    final ownerProfileId = profileState?.activeProfileId;

    await _addRecording(
      channelName: channelName,
      programName: programName,
      startTime: startTime,
      endTime: endTime,
      channelId: channelId,
      channelLogoUrl: channelLogoUrl,
      streamUrl: streamUrl,
      isRecurring: isRecurring,
      recurDays: recurDays,
      profile: profile ?? _defaultProfile,
      ownerProfileId: ownerProfileId,
      isShared: isShared,
    );
    return true;
  }

  Future<void> _addRecording({
    required String channelName,
    required String programName,
    required DateTime startTime,
    required DateTime endTime,
    String? channelId,
    String? channelLogoUrl,
    String? streamUrl,
    bool isRecurring = false,
    int recurDays = 0,
    RecordingProfile profile = RecordingProfile.original,
    String? ownerProfileId,
    bool isShared = true,
  }) async {
    final id = 'rec_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
    final recording = Recording(
      id: id,
      channelId: channelId,
      channelName: channelName,
      channelLogoUrl: channelLogoUrl,
      programName: programName,
      streamUrl: streamUrl,
      startTime: startTime,
      endTime: endTime,
      isRecurring: isRecurring,
      recurDays: recurDays,
      profile: profile,
      ownerProfileId: ownerProfileId,
      isShared: isShared,
    );

    debugPrint(
      'DvrService: scheduling recording "$programName" '
      'with profile ${profile.label}, owner=$ownerProfileId',
    );

    // Persist to DB.
    await _cache.saveRecording(recording);

    final current = state.value?.recordings ?? [];
    state = AsyncData(DvrState(recordings: [...current, recording]));
  }

  /// Starts a recording — begins stream capture
  /// if URL is available.
  Future<void> startRecording(String id) async {
    await _updateStatus(id, RecordingStatus.recording);

    final rec = state.value?.recordings.firstWhereOrNull((r) => r.id == id);
    if (rec?.streamUrl != null && !kIsWeb) {
      _capture.captureStream(rec!);
    }
  }

  /// Completes a recording with file info.
  Future<void> completeRecording(
    String id, {
    required String filePath,
    required int fileSizeBytes,
  }) async {
    final updated =
        (state.value?.recordings ?? []).map((r) {
          if (r.id != id) return r;
          return r.copyWith(
            status: RecordingStatus.completed,
            filePath: filePath,
            fileSizeBytes: fileSizeBytes,
          );
        }).toList();

    final rec = updated.firstWhereOrNull((r) => r.id == id);
    if (rec == null) return;
    await _cache.updateRecording(rec);
    state = AsyncData(DvrState(recordings: updated));
  }

  /// Marks a recording as failed.
  Future<void> failRecording(String id) async {
    _engine.stopCapture(id);
    await _updateStatus(id, RecordingStatus.failed);
  }

  /// Stops an in-progress recording early,
  /// marking it as completed.
  Future<void> stopRecording(String id) async {
    await _capture.stopAndComplete(id);
  }

  /// Updates the auto-delete [policy] and [keepEpisodeCount] for
  /// the recording identified by [id].
  ///
  /// Persists the change to the backend and updates in-memory state.
  Future<void> updateAutoDeletePolicy({
    required String id,
    required AutoDeletePolicy policy,
    required int keepEpisodeCount,
  }) async {
    final updated =
        (state.value?.recordings ?? []).map((r) {
          if (r.id != id) return r;
          return r.copyWith(
            autoDeletePolicy: policy,
            keepEpisodeCount: keepEpisodeCount,
          );
        }).toList();

    final rec = updated.firstWhereOrNull((r) => r.id == id);
    if (rec == null) return;
    await _cache.updateRecording(rec);
    state = AsyncData(
      DvrState(
        recordings: updated,
        progressBytes: state.value?.progressBytes ?? {},
      ),
    );
  }

  /// Cancels/removes a recording, deleting the file if it exists.
  /// Returns `true` if the local file for [filePath] exists on disk.
  ///
  /// Always returns `true` on web (no local filesystem). Use this
  /// instead of calling [File.exists] directly in the presentation
  /// layer.
  Future<bool> recordingFileExists(String filePath) async {
    if (kIsWeb) return true;
    return File(filePath).exists();
  }

  ///
  /// Returns false if permission denied.
  Future<bool> removeRecording(String id) async {
    final current = state.value?.recordings ?? [];
    final rec = current.where((r) => r.id == id).firstOrNull;
    if (rec == null) return false;

    // Check permission to delete
    final permissionGuard = ref.read(permissionGuardProvider);
    if (!permissionGuard.canDeleteRecording(
      ownerProfileId: rec.ownerProfileId,
      isShared: rec.isShared,
    )) {
      debugPrint('DvrService: permission denied for deleting recording');
      return false;
    }

    _engine.stopCapture(id);

    // Delete file if exists (native only).
    if (!kIsWeb && rec.filePath != null) {
      try {
        final file = File(rec.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete recording file: $e');
      }
    }

    // Clean up progress state.
    final newProgress = Map<String, int>.from(state.value?.progressBytes ?? {});
    newProgress.remove(id);

    await _cache.deleteRecording(id);
    state = AsyncData(
      DvrState(
        recordings: current.where((r) => r.id != id).toList(),
        progressBytes: newProgress,
      ),
    );
    return true;
  }

  Future<void> _updateStatus(String id, RecordingStatus status) async {
    final updated =
        (state.value?.recordings ?? []).map((r) {
          if (r.id != id) return r;
          return r.copyWith(status: status);
        }).toList();

    final rec = updated.firstWhereOrNull((r) => r.id == id);
    if (rec == null) return;
    await _cache.updateRecording(rec);
    state = AsyncData(DvrState(recordings: updated));
  }

  /// Periodically checks if any scheduled recordings should start.
  void _checkScheduledRecordings() {
    final recordings = state.value?.recordings ?? [];
    if (recordings.isEmpty) return;

    final now = DateTime.now();
    // Serialize in the camelCase epoch-ms format expected by Rust.
    final recordingsJson = buildRecordingsCheckJson(recordings);

    _backend
        .getRecordingsToStart(recordingsJson, now.millisecondsSinceEpoch)
        .then((resultJson) {
          final ids = (jsonDecode(resultJson) as List).cast<String>();
          for (final id in ids) {
            startRecording(id);
          }
        })
        .catchError((Object e) {
          debugPrint('DvrService: _checkScheduledRecordings error: $e');
        });
  }

  // ── Playback / transfer ops ────────────────────────────

  /// Attempts to start playback of a completed recording.
  ///
  /// Checks that the local file exists, then starts playback
  /// via [PlaybackSessionNotifier]. Returns `true` on success,
  /// `false` if the file is missing or [recording] has no path.
  Future<bool> playRecording(Recording recording) async {
    if (recording.filePath == null || recording.filePath!.isEmpty) {
      return false;
    }

    final exists = await recordingFileExists(recording.filePath!);
    if (!exists) return false;

    ref
        .read(playbackSessionProvider.notifier)
        .startPlayback(
          streamUrl: recording.filePath!,
          isLive: false,
          channelName: recording.programName,
          channelLogoUrl: recording.channelLogoUrl,
          currentProgram: recording.channelName,
        );
    return true;
  }

  /// Queues an upload for [recordingId] to the default
  /// storage backend. No-op if no backend is configured.
  void queueUpload(String recordingId) {
    final backends = ref.read(storageBackendsProvider);
    final backend =
        backends.where((b) => b.isDefault).firstOrNull ?? backends.firstOrNull;
    if (backend == null) return;

    ref
        .read(transferServiceProvider.notifier)
        .queueUpload(recordingId, backend.id);
  }

  /// Queues a download for [recording] from its remote backend.
  /// No-op if [recording] has no [Recording.remoteBackendId].
  void queueDownload(Recording recording) {
    if (recording.remoteBackendId == null) return;

    ref
        .read(transferServiceProvider.notifier)
        .queueDownload(
          recording.id,
          recording.remoteBackendId!,
          remotePath: recording.remotePath,
        );
  }

  // ── Recurring expansion ─────────────────────────────────

  /// Expands recurring recordings into scheduled
  /// instances for the next 7 days.
  ///
  /// Delegates the bitmask/weekday expansion
  /// algorithm to the Rust backend and creates
  /// new [Recording] entries for each instance.
  Future<void> _expandRecurringRecordings() async {
    final recordings = state.value?.recordings ?? [];
    if (recordings.isEmpty) return;

    final now = DateTime.now();
    final recordingsJson = jsonEncode(recordings.map(recordingToMap).toList());

    final resultJson = await _backend.expandRecurringRecordings(
      recordingsJson,
      now.millisecondsSinceEpoch,
    );

    final instances =
        (jsonDecode(resultJson) as List<dynamic>).cast<Map<String, dynamic>>();

    for (final inst in instances) {
      await _addRecording(
        channelName: inst['channel_name'] as String,
        programName: inst['program_name'] as String,
        startTime: DateTime.parse(inst['start_time'] as String),
        endTime: DateTime.parse(inst['end_time'] as String),
        channelId: inst['channel_id'] as String?,
        channelLogoUrl: inst['channel_logo_url'] as String?,
        streamUrl: inst['stream_url'] as String?,
        isRecurring: false,
        recurDays: 0,
        ownerProfileId: inst['owner_profile_id'] as String?,
        isShared: inst['is_shared'] as bool? ?? true,
      );
    }
  }
}

final dvrServiceProvider = AsyncNotifierProvider<DvrService, DvrState>(
  DvrService.new,
);
