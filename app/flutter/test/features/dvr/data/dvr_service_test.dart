import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/app_directories.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/dvr/data/dvr_service.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/recording.dart';
import 'package:crispy_tivi/features/dvr/domain/utils/dvr_payload.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/recording_profile.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/dvr_permission.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/user_role.dart';
import 'package:crispy_tivi/features/profiles/presentation/providers/permission_guard.dart';

/// Mock permission guard that allows all DVR
/// operations.
class _MockPermissionGuard implements PermissionGuard {
  @override
  bool get isAdmin => true;

  @override
  bool get canAccessSettings => true;

  @override
  bool get canManageProfiles => true;

  @override
  bool get hasAllSourceAccess => true;

  @override
  UserRole get currentRole => UserRole.admin;

  @override
  bool get canViewRecordings => true;

  @override
  bool get canScheduleRecordings => true;

  @override
  DvrPermission get dvrPermission => DvrPermission.full;

  @override
  bool canViewRecording({
    required String? ownerProfileId,
    required bool isShared,
  }) => true;

  @override
  bool canDeleteRecording({
    required String? ownerProfileId,
    required bool isShared,
  }) => true;

  @override
  Future<bool> hasSourceAccess(String sourceId) async => true;

  @override
  Future<List<String>?> getAccessibleSources() async => null;

  @override
  bool canViewRating(int rating) => true;

  @override
  int get maxAllowedRating => 4;

  @override
  bool requiresAdmin() => true;

  @override
  bool requiresViewer() => true;

  @override
  bool requiresFullDvr() => true;
}

/// Naive datetime regex: no timezone suffix, no
/// fractional seconds (matches Rust NaiveDateTime
/// serde format `"YYYY-MM-DDTHH:mm:ss"`).
final _naiveDateTimeRe = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$');

void main() {
  // ── recordingToMap datetime format ─────────────

  group('recordingToMap', () {
    test('serializes start_time as naive datetime '
        '(no timezone, no fractional seconds)', () {
      final recording = Recording(
        id: 'test-id',
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime.utc(2024, 1, 1, 15, 0, 0),
        endTime: DateTime.utc(2024, 1, 1, 16, 0, 0),
      );

      final map = recordingToMap(recording);

      expect(
        map['start_time'] as String,
        matches(_naiveDateTimeRe),
        reason:
            'start_time must be NaiveDateTime format '
            '(no timezone suffix, no fractional seconds)',
      );
    });

    test('serializes end_time as naive datetime '
        '(no timezone, no fractional seconds)', () {
      final recording = Recording(
        id: 'test-id',
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime.utc(2024, 1, 1, 15, 0, 0),
        endTime: DateTime.utc(2024, 1, 1, 16, 30, 45),
      );

      final map = recordingToMap(recording);

      expect(
        map['end_time'] as String,
        matches(_naiveDateTimeRe),
        reason:
            'end_time must be NaiveDateTime format '
            '(no timezone suffix, no fractional seconds)',
      );
    });

    test('datetime values are correctly formatted', () {
      final recording = Recording(
        id: 'test-id',
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime.utc(2024, 6, 15, 20, 30, 0),
        endTime: DateTime.utc(2024, 6, 15, 21, 45, 0),
      );

      final map = recordingToMap(recording);

      expect(map['start_time'], '2024-06-15T20:30:00');
      expect(map['end_time'], '2024-06-15T21:45:00');
    });

    test('rejects ISO 8601 format with timezone suffix', () {
      final recording = Recording(
        id: 'test-id',
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime.utc(2024, 1, 1, 15, 0, 0),
        endTime: DateTime.utc(2024, 1, 1, 16, 0, 0),
      );

      final map = recordingToMap(recording);

      // Must NOT end with 'Z' or contain fractional
      // seconds — Rust NaiveDateTime cannot parse
      // ISO 8601 strings with timezone info.
      expect(
        (map['start_time'] as String).endsWith('Z'),
        isFalse,
        reason: 'start_time must not have UTC "Z" suffix',
      );
      expect(
        (map['end_time'] as String).endsWith('Z'),
        isFalse,
        reason: 'end_time must not have UTC "Z" suffix',
      );
    });
  });

  late ProviderContainer container;
  late CrispyBackend backend;

  setUp(() {
    AppDirectories.testRoot = Directory.systemTemp.path;
    backend = MemoryBackend();

    container = ProviderContainer(
      overrides: [
        crispyBackendProvider.overrideWithValue(backend),
        cacheServiceProvider.overrideWithValue(CacheService(backend)),
        permissionGuardProvider.overrideWithValue(_MockPermissionGuard()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// Read DVR state, handling AsyncNotifier loading.
  Future<DvrState> readState() async {
    // Wait for async build to complete.
    final notifier = container.read(dvrServiceProvider.notifier);
    // Force the future to complete.
    await notifier.future;
    final asyncVal = container.read(dvrServiceProvider);
    return asyncVal.asData?.value ?? const DvrState();
  }

  group('DvrService', () {
    test('starts with empty recordings', () async {
      final state = await readState();
      expect(state.recordings, isEmpty);
    });

    test('scheduleRecording adds a recording', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );

      final state = await readState();
      expect(state.recordings.length, 1);
      expect(state.recordings.first.channelName, 'CNN');
      expect(state.recordings.first.status, RecordingStatus.scheduled);
    });

    test('scheduleRecording detects same-channel time conflicts', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );

      // Overlapping, same channel -> conflict.
      final result = await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'Late News',
        startTime: DateTime(2025, 1, 1, 20, 30),
        endTime: DateTime(2025, 1, 1, 21, 30),
      );

      expect(result, ScheduleResult.conflict);
      final state = await readState();
      expect(state.recordings.length, 1);
    });

    test('scheduleRecording allows different channel overlap', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );
      await notifier.scheduleRecording(
        channelName: 'BBC',
        programName: 'World',
        startTime: DateTime(2025, 1, 1, 20, 30),
        endTime: DateTime(2025, 1, 1, 21, 30),
      );

      final state = await readState();
      expect(state.recordings.length, 2);
    });

    test('startRecording changes status', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );

      var state = await readState();
      await notifier.startRecording(state.recordings.first.id);

      state = await readState();
      expect(state.recordings.first.status, RecordingStatus.recording);
    });

    test('completeRecording sets file info', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );

      var state = await readState();
      final id = state.recordings.first.id;
      await notifier.startRecording(id);
      await notifier.completeRecording(
        id,
        filePath: '/dvr/news.ts',
        fileSizeBytes: 1024000,
      );

      state = await readState();
      expect(state.recordings.first.status, RecordingStatus.completed);
      expect(state.recordings.first.filePath, '/dvr/news.ts');
      expect(state.recordings.first.fileSizeBytes, 1024000);
    });

    test('failRecording sets status to failed', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );

      var state = await readState();
      final id = state.recordings.first.id;
      await notifier.startRecording(id);
      await notifier.failRecording(id);

      state = await readState();
      expect(state.recordings.first.status, RecordingStatus.failed);
    });

    test('removeRecording removes a recording', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );

      var state = await readState();
      await notifier.removeRecording(state.recordings.first.id);

      state = await readState();
      expect(state.recordings, isEmpty);
    });

    test('filtered lists return correct subsets', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News 1',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );
      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News 2',
        startTime: DateTime(2025, 1, 2, 20),
        endTime: DateTime(2025, 1, 2, 21),
      );

      var state = await readState();
      expect(state.scheduled.length, 2);
      expect(state.inProgress, isEmpty);

      await notifier.startRecording(state.recordings.first.id);

      state = await readState();
      expect(state.scheduled.length, 1);
      expect(state.inProgress.length, 1);
    });

    test('totalStorageBytes sums completed recordings', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'News',
        startTime: DateTime(2025, 1, 1, 20),
        endTime: DateTime(2025, 1, 1, 21),
      );

      var state = await readState();
      final id = state.recordings.first.id;
      await notifier.startRecording(id);
      await notifier.completeRecording(
        id,
        filePath: '/dvr/a.ts',
        fileSizeBytes: 500000,
      );

      state = await readState();
      expect(state.totalStorageBytes, 500000);
    });

    test('persistence survives reload', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'CNN',
        programName: 'Persisted Test',
        startTime: DateTime(2025, 6, 1, 20),
        endTime: DateTime(2025, 6, 1, 21),
        streamUrl: 'http://example.com/live.ts',
      );

      // Verify recording is in the cache.
      final cache = container.read(cacheServiceProvider);
      final dbRecordings = await cache.loadRecordings();
      expect(dbRecordings.length, 1);
      expect(dbRecordings.first.programName, 'Persisted Test');
      expect(dbRecordings.first.streamUrl, 'http://example.com/live.ts');
    });

    test('recurring recording has correct flags', () async {
      final notifier = container.read(dvrServiceProvider.notifier);
      await notifier.future;

      await notifier.scheduleRecording(
        channelName: 'HBO',
        programName: 'Daily Show',
        startTime: DateTime(2025, 1, 1, 22),
        endTime: DateTime(2025, 1, 1, 23),
        isRecurring: true,
        recurDays: 127, // all days
      );

      final state = await readState();
      expect(state.recordings.first.isRecurring, isTrue);
      expect(state.recordings.first.recurDays, 127);
    });

    // ── forceScheduleRecording ────────────────────

    group('forceScheduleRecording', () {
      test('adds recording even with time conflict', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        // Schedule first recording.
        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        // Force-schedule overlapping on different
        // channel — should succeed despite conflict.
        final ok = await notifier.forceScheduleRecording(
          channelName: 'BBC',
          programName: 'World',
          startTime: DateTime(2025, 1, 1, 20, 30),
          endTime: DateTime(2025, 1, 1, 21, 30),
        );

        expect(ok, isTrue);
        final state = await readState();
        expect(state.recordings.length, 2);
      });

      test('uses custom profile when specified', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.forceScheduleRecording(
          channelName: 'HBO',
          programName: 'Movie',
          startTime: DateTime(2025, 2, 1, 20),
          endTime: DateTime(2025, 2, 1, 22),
          profile: RecordingProfile.low,
        );

        final state = await readState();
        expect(state.recordings.first.profile, RecordingProfile.low);
      });

      test('uses default profile when none specified', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        notifier.setDefaultProfile(RecordingProfile.medium);

        await notifier.forceScheduleRecording(
          channelName: 'HBO',
          programName: 'Movie',
          startTime: DateTime(2025, 2, 1, 20),
          endTime: DateTime(2025, 2, 1, 22),
        );

        final state = await readState();
        expect(state.recordings.first.profile, RecordingProfile.medium);
      });
    });

    // ── Status transition sequences ───────────────

    group('status transitions', () {
      test('scheduled -> recording -> completed', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        var state = await readState();
        final id = state.recordings.first.id;

        expect(state.recordings.first.status, RecordingStatus.scheduled);

        await notifier.startRecording(id);
        state = await readState();
        expect(state.recordings.first.status, RecordingStatus.recording);

        await notifier.completeRecording(
          id,
          filePath: '/dvr/news.ts',
          fileSizeBytes: 2048000,
        );
        state = await readState();
        expect(state.recordings.first.status, RecordingStatus.completed);
        expect(state.recordings.first.filePath, '/dvr/news.ts');
        expect(state.recordings.first.fileSizeBytes, 2048000);
      });

      test('scheduled -> recording -> failed', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        var state = await readState();
        final id = state.recordings.first.id;

        await notifier.startRecording(id);
        await notifier.failRecording(id);

        state = await readState();
        expect(state.recordings.first.status, RecordingStatus.failed);
      });
    });

    // ── stopRecording ─────────────────────────────

    group('stopRecording', () {
      test('marks in-progress recording as completed', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        var state = await readState();
        final id = state.recordings.first.id;

        await notifier.startRecording(id);
        state = await readState();
        expect(state.recordings.first.status, RecordingStatus.recording);

        await notifier.stopRecording(id);
        state = await readState();
        expect(state.recordings.first.status, RecordingStatus.completed);
      });

      test('does nothing for non-recording status', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        var state = await readState();
        final id = state.recordings.first.id;

        // Still in 'scheduled' status.
        await notifier.stopRecording(id);

        state = await readState();
        expect(state.recordings.first.status, RecordingStatus.scheduled);
      });
    });

    // ── removeRecording ───────────────────────────

    group('removeRecording', () {
      test('returns false for nonexistent ID', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        final result = await notifier.removeRecording('nonexistent_id');
        expect(result, isFalse);
      });

      test('returns true and removes existing recording', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        var state = await readState();
        final id = state.recordings.first.id;

        final result = await notifier.removeRecording(id);
        expect(result, isTrue);

        state = await readState();
        expect(state.recordings, isEmpty);
      });

      test('can remove a completed recording', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        var state = await readState();
        final id = state.recordings.first.id;

        await notifier.startRecording(id);
        await notifier.completeRecording(
          id,
          filePath: '/dvr/news.ts',
          fileSizeBytes: 1000,
        );

        final result = await notifier.removeRecording(id);
        expect(result, isTrue);

        state = await readState();
        expect(state.recordings, isEmpty);
      });
    });

    // ── Edge cases ────────────────────────────────

    group('edge cases', () {
      test('scheduling duplicate program/channel '
          'succeeds when non-overlapping', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        final result = await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 2, 20),
          endTime: DateTime(2025, 1, 2, 21),
        );

        expect(result, ScheduleResult.scheduled);
        final state = await readState();
        expect(state.recordings.length, 2);
      });

      test('setDefaultProfile changes default', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        expect(notifier.defaultProfile, RecordingProfile.original);

        notifier.setDefaultProfile(RecordingProfile.high);
        expect(notifier.defaultProfile, RecordingProfile.high);
      });

      test('DvrState helper getters are correct', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        // Schedule 3 recordings on same channel.
        for (var i = 1; i <= 3; i++) {
          await notifier.scheduleRecording(
            channelName: 'CNN',
            programName: 'News $i',
            startTime: DateTime(2025, 1, i, 20),
            endTime: DateTime(2025, 1, i, 21),
          );
        }

        var state = await readState();
        // Start recording #1.
        await notifier.startRecording(state.recordings[0].id);
        // Complete recording #2.
        await notifier.startRecording(state.recordings[1].id);
        state = await readState();
        await notifier.completeRecording(
          state.recordings[1].id,
          filePath: '/dvr/news2.ts',
          fileSizeBytes: 500,
        );

        state = await readState();
        expect(state.scheduled.length, 1);
        expect(state.inProgress.length, 1);
        expect(state.completed.length, 1);
        expect(state.totalStorageBytes, 500);
      });

      test('totalStorageMB formats correctly', () async {
        final notifier = container.read(dvrServiceProvider.notifier);
        await notifier.future;

        await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        var state = await readState();
        final id = state.recordings.first.id;
        await notifier.startRecording(id);
        await notifier.completeRecording(
          id,
          filePath: '/dvr/news.ts',
          fileSizeBytes: 1048576, // exactly 1 MB
        );

        state = await readState();
        expect(state.totalStorageMB, '1.0 MB');
      });
    });

    // ── Permission denied ─────────────────────────

    group('permission denied', () {
      late ProviderContainer restrictedContainer;

      setUp(() {
        restrictedContainer = ProviderContainer(
          overrides: [
            crispyBackendProvider.overrideWithValue(backend),
            cacheServiceProvider.overrideWithValue(CacheService(backend)),
            permissionGuardProvider.overrideWithValue(
              _DenySchedulePermissionGuard(),
            ),
          ],
        );
      });

      tearDown(() {
        restrictedContainer.dispose();
      });

      Future<DvrState> readRestrictedState() async {
        final notifier = restrictedContainer.read(dvrServiceProvider.notifier);
        await notifier.future;
        final asyncVal = restrictedContainer.read(dvrServiceProvider);
        return asyncVal.asData?.value ?? const DvrState();
      }

      test('scheduleRecording returns permissionDenied '
          'when permission denied', () async {
        final notifier = restrictedContainer.read(dvrServiceProvider.notifier);
        await notifier.future;

        final result = await notifier.scheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        expect(result, ScheduleResult.permissionDenied);
        final state = await readRestrictedState();
        expect(state.recordings, isEmpty);
      });

      test('forceScheduleRecording returns false '
          'when permission denied', () async {
        final notifier = restrictedContainer.read(dvrServiceProvider.notifier);
        await notifier.future;

        final ok = await notifier.forceScheduleRecording(
          channelName: 'CNN',
          programName: 'News',
          startTime: DateTime(2025, 1, 1, 20),
          endTime: DateTime(2025, 1, 1, 21),
        );

        expect(ok, isFalse);
        final state = await readRestrictedState();
        expect(state.recordings, isEmpty);
      });
    });
  });
}

/// Mock permission guard that denies scheduling.
class _DenySchedulePermissionGuard implements PermissionGuard {
  @override
  bool get isAdmin => false;

  @override
  bool get canAccessSettings => false;

  @override
  bool get canManageProfiles => false;

  @override
  bool get hasAllSourceAccess => false;

  @override
  UserRole get currentRole => UserRole.restricted;

  @override
  bool get canViewRecordings => false;

  @override
  bool get canScheduleRecordings => false;

  @override
  DvrPermission get dvrPermission => DvrPermission.none;

  @override
  bool canViewRecording({
    required String? ownerProfileId,
    required bool isShared,
  }) => false;

  @override
  bool canDeleteRecording({
    required String? ownerProfileId,
    required bool isShared,
  }) => false;

  @override
  Future<bool> hasSourceAccess(String sourceId) async => false;

  @override
  Future<List<String>?> getAccessibleSources() async => [];

  @override
  bool canViewRating(int rating) => false;

  @override
  int get maxAllowedRating => 0;

  @override
  bool requiresAdmin() => false;

  @override
  bool requiresViewer() => false;

  @override
  bool requiresFullDvr() => false;
}
