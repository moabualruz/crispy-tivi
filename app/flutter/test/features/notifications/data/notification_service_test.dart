import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/features/notifications/data/'
    'notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCrispyBackend extends Mock implements CrispyBackend {}

class MockCacheService extends Mock implements CacheService {}

void main() {
  late ProviderContainer container;
  late MockCacheService mockCache;
  late MockCrispyBackend mockBackend;

  setUp(() {
    mockCache = MockCacheService();
    mockBackend = MockCrispyBackend();

    // Default stubs.
    when(
      () => mockCache.loadReminders(),
    ).thenAnswer((_) async => <Map<String, dynamic>>[]);
    when(() => mockCache.saveReminder(any())).thenAnswer((_) async {});
    when(() => mockCache.deleteReminder(any())).thenAnswer((_) async {});
    when(() => mockCache.markReminderFired(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        cacheServiceProvider.overrideWithValue(mockCache),
        crispyBackendProvider.overrideWithValue(mockBackend),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// Read the current notification state.
  NotificationState readState() {
    return container.read(notificationServiceProvider);
  }

  /// Get the notifier instance.
  NotificationService notifier() {
    return container.read(notificationServiceProvider.notifier);
  }

  group('NotificationService', () {
    group('build (initial state)', () {
      test('starts with empty toasts', () {
        final state = readState();
        expect(state.toasts, isEmpty);
      });

      test('starts with empty reminders when DB empty', () {
        final state = readState();
        expect(state.reminders, isEmpty);
      });

      test('starts with enabled=true', () {
        final state = readState();
        expect(state.enabled, isTrue);
      });
    });

    group('showToast', () {
      test('adds a toast to state', () {
        notifier().showToast('Hello');

        final state = readState();
        expect(state.toasts.length, 1);
        expect(state.toasts.first.message, 'Hello');
      });

      test('defaults to ToastType.info', () {
        notifier().showToast('Info message');

        final state = readState();
        expect(state.toasts.first.type, ToastType.info);
      });

      test('accepts custom toast type', () {
        notifier().showToast('Error!', type: ToastType.error);

        final state = readState();
        expect(state.toasts.first.type, ToastType.error);
      });

      test('accepts warning toast type', () {
        notifier().showToast('Warn!', type: ToastType.warning);

        final state = readState();
        expect(state.toasts.first.type, ToastType.warning);
      });

      test('accepts success toast type', () {
        notifier().showToast('Done!', type: ToastType.success);

        final state = readState();
        expect(state.toasts.first.type, ToastType.success);
      });

      test('assigns non-empty ID', () {
        notifier().showToast('Toast');

        final state = readState();
        expect(state.toasts.first.id, isNotEmpty);
      });

      test('records createdAt timestamp', () {
        final before = DateTime.now();
        notifier().showToast('Timed');
        final after = DateTime.now();

        final toast = readState().toasts.first;
        expect(
          toast.createdAt.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch),
        );
        expect(
          toast.createdAt.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch),
        );
      });

      test('accumulates multiple toasts', () {
        notifier().showToast('A');
        notifier().showToast('B');
        notifier().showToast('C');

        expect(readState().toasts.length, 3);
      });
    });

    group('dismissToast', () {
      test('removes toast by ID', () {
        notifier().showToast('To dismiss');
        final id = readState().toasts.first.id;

        notifier().dismissToast(id);

        expect(readState().toasts, isEmpty);
      });

      test('does nothing for unknown ID', () {
        notifier().showToast('Keep me');

        notifier().dismissToast('nonexistent-id');

        expect(readState().toasts.length, 1);
      });

      test('removes matching toast by ID filter', () {
        // dismissToast filters by ID using
        // `where((t) => t.id != id)`.
        // Verify the filter works with a known ID.
        notifier().showToast('A');
        final toasts = readState().toasts;
        expect(toasts.length, 1);
        final aId = toasts.first.id;

        notifier().dismissToast(aId);
        expect(readState().toasts, isEmpty);

        // Now add another toast and verify it
        // persists after dismissing different ID.
        notifier().showToast('B');
        final bToasts = readState().toasts;
        expect(bToasts.length, 1);

        notifier().dismissToast('definitely-wrong');
        expect(readState().toasts.length, 1);
        expect(readState().toasts.first.message, 'B');
      });
    });

    group('addReminder', () {
      test('adds reminder to state', () {
        notifier().addReminder(
          programName: 'Movie Night',
          channelName: 'HBO',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        final reminders = readState().reminders;
        expect(reminders.length, 1);
        expect(reminders.first.programName, 'Movie Night');
        expect(reminders.first.channelName, 'HBO');
      });

      test('sets notifyAt to 5 minutes before start', () {
        final startTime = DateTime(2026, 3, 1, 20, 0);

        notifier().addReminder(
          programName: 'Show',
          channelName: 'CH1',
          startTime: startTime,
        );

        final reminder = readState().reminders.first;
        expect(
          reminder.notifyAt,
          startTime.subtract(const Duration(minutes: 5)),
        );
      });

      test('assigns ID starting with rem_', () {
        notifier().addReminder(
          programName: 'P1',
          channelName: 'C1',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        final reminder = readState().reminders.first;
        expect(reminder.id, startsWith('rem_'));
      });

      test('persists reminder to cache', () {
        notifier().addReminder(
          programName: 'Saved',
          channelName: 'CH',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        verify(
          () => mockCache.saveReminder(
            any(
              that: isA<Map<String, dynamic>>().having(
                (m) => m['program_name'],
                'program_name',
                'Saved',
              ),
            ),
          ),
        ).called(1);
      });

      test('shows confirmation toast', () {
        notifier().addReminder(
          programName: 'My Show',
          channelName: 'ABC',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        final toasts = readState().toasts;
        expect(toasts, isNotEmpty);
        expect(toasts.first.message, contains('My Show'));
        expect(toasts.first.type, ToastType.success);
      });

      test('reminder starts as not fired', () {
        notifier().addReminder(
          programName: 'P',
          channelName: 'C',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        expect(readState().reminders.first.fired, isFalse);
      });

      test('stores correct startTime', () {
        final start = DateTime(2026, 6, 15, 21, 30);
        notifier().addReminder(
          programName: 'Late Show',
          channelName: 'NBC',
          startTime: start,
        );

        expect(readState().reminders.first.startTime, start);
      });
    });

    group('removeReminder', () {
      test('removes reminder from state', () {
        notifier().addReminder(
          programName: 'Remove Me',
          channelName: 'CH',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        final id = readState().reminders.first.id;
        notifier().removeReminder(id);

        expect(readState().reminders, isEmpty);
      });

      test('deletes reminder from cache', () {
        notifier().addReminder(
          programName: 'Delete Me',
          channelName: 'CH',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        final id = readState().reminders.first.id;
        notifier().removeReminder(id);

        verify(() => mockCache.deleteReminder(id)).called(1);
      });

      test('does nothing for unknown ID', () {
        notifier().addReminder(
          programName: 'Keep',
          channelName: 'CH',
          startTime: DateTime(2026, 3, 1, 20, 0),
        );

        notifier().removeReminder('unknown');

        expect(readState().reminders.length, 1);
      });
    });

    group('showSyncStatus', () {
      test('shows toast with channel count', () {
        notifier().showSyncStatus(150);

        final toasts = readState().toasts;
        expect(toasts.length, 1);
        expect(toasts.first.message, 'Synced 150 channels');
        expect(toasts.first.type, ToastType.success);
      });

      test('shows toast with zero count', () {
        notifier().showSyncStatus(0);

        expect(readState().toasts.first.message, 'Synced 0 channels');
      });

      test('is a success toast', () {
        notifier().showSyncStatus(42);

        expect(readState().toasts.first.type, ToastType.success);
      });
    });

    group('showRecordingStarted', () {
      test('shows info toast with program name', () {
        notifier().showRecordingStarted('Evening News');

        final toast = readState().toasts.first;
        expect(toast.message, 'Recording started: Evening News');
        expect(toast.type, ToastType.info);
      });

      test('includes program name in message', () {
        notifier().showRecordingStarted('Test');

        expect(readState().toasts.first.message, contains('Test'));
      });

      test('creates exactly one toast', () {
        notifier().showRecordingStarted('Show');

        expect(readState().toasts.length, 1);
      });
    });

    group('showRecordingCompleted', () {
      test('shows success toast', () {
        notifier().showRecordingCompleted('Movie');

        final toast = readState().toasts.first;
        expect(toast.message, 'Recording complete: Movie');
        expect(toast.type, ToastType.success);
      });

      test('includes program name', () {
        notifier().showRecordingCompleted('Special Event');

        expect(readState().toasts.first.message, contains('Special Event'));
      });

      test('is a success type toast', () {
        notifier().showRecordingCompleted('X');

        expect(readState().toasts.first.type, ToastType.success);
      });
    });

    group('showRecordingFailed', () {
      test('shows error toast', () {
        notifier().showRecordingFailed('Failed Show');

        final toast = readState().toasts.first;
        expect(toast.message, 'Recording failed: Failed Show');
        expect(toast.type, ToastType.error);
      });

      test('includes program name', () {
        notifier().showRecordingFailed('My Program');

        expect(readState().toasts.first.message, contains('My Program'));
      });

      test('is an error type toast', () {
        notifier().showRecordingFailed('X');

        expect(readState().toasts.first.type, ToastType.error);
      });
    });
  });

  group('NotificationState', () {
    group('copyWith', () {
      test('creates copy with updated toasts', () {
        const state = NotificationState();
        final toast = AppToast(
          id: '1',
          message: 'test',
          type: ToastType.info,
          createdAt: DateTime(2026),
        );
        final copy = state.copyWith(toasts: [toast]);
        expect(copy.toasts.length, 1);
        expect(copy.reminders, isEmpty);
        expect(copy.enabled, isTrue);
      });

      test('creates copy with updated enabled', () {
        const state = NotificationState();
        final copy = state.copyWith(enabled: false);
        expect(copy.enabled, isFalse);
        expect(copy.toasts, isEmpty);
      });

      test('preserves existing values when not '
          'overridden', () {
        final reminder = ProgramReminder(
          id: 'r1',
          programName: 'Show',
          channelName: 'CH',
          startTime: DateTime(2026),
          notifyAt: DateTime(2026),
        );
        final state = NotificationState(reminders: [reminder], enabled: false);
        final copy = state.copyWith();

        expect(copy.reminders.length, 1);
        expect(copy.enabled, isFalse);
        expect(copy.toasts, isEmpty);
      });

      test('creates copy with updated reminders', () {
        const state = NotificationState();
        final reminder = ProgramReminder(
          id: 'r1',
          programName: 'Show',
          channelName: 'CH',
          startTime: DateTime(2026),
          notifyAt: DateTime(2026),
        );
        final copy = state.copyWith(reminders: [reminder]);
        expect(copy.reminders.length, 1);
        expect(copy.reminders.first.programName, 'Show');
      });
    });

    group('default constructor', () {
      test('has empty toasts list', () {
        const state = NotificationState();
        expect(state.toasts, isEmpty);
      });

      test('has empty reminders list', () {
        const state = NotificationState();
        expect(state.reminders, isEmpty);
      });

      test('has enabled=true by default', () {
        const state = NotificationState();
        expect(state.enabled, isTrue);
      });
    });
  });

  group('AppToast', () {
    test('stores all fields', () {
      final now = DateTime.now();
      final toast = AppToast(
        id: 'toast-1',
        message: 'Hello',
        type: ToastType.warning,
        createdAt: now,
      );
      expect(toast.id, 'toast-1');
      expect(toast.message, 'Hello');
      expect(toast.type, ToastType.warning);
      expect(toast.createdAt, now);
    });

    test('stores error type', () {
      final toast = AppToast(
        id: 'e1',
        message: 'Err',
        type: ToastType.error,
        createdAt: DateTime(2026),
      );
      expect(toast.type, ToastType.error);
    });

    test('stores success type', () {
      final toast = AppToast(
        id: 's1',
        message: 'OK',
        type: ToastType.success,
        createdAt: DateTime(2026),
      );
      expect(toast.type, ToastType.success);
    });
  });

  group('ProgramReminder', () {
    test('stores all fields', () {
      final start = DateTime(2026, 3, 1, 20, 0);
      final notify = DateTime(2026, 3, 1, 19, 55);
      final r = ProgramReminder(
        id: 'rem-1',
        programName: 'News',
        channelName: 'CNN',
        startTime: start,
        notifyAt: notify,
        fired: true,
      );
      expect(r.id, 'rem-1');
      expect(r.programName, 'News');
      expect(r.channelName, 'CNN');
      expect(r.startTime, start);
      expect(r.notifyAt, notify);
      expect(r.fired, isTrue);
    });

    test('defaults fired to false', () {
      final r = ProgramReminder(
        id: 'rem-2',
        programName: 'Show',
        channelName: 'CH',
        startTime: DateTime(2026),
        notifyAt: DateTime(2026),
      );
      expect(r.fired, isFalse);
    });

    test('stores channel name', () {
      final r = ProgramReminder(
        id: 'rem-3',
        programName: 'Game',
        channelName: 'ESPN',
        startTime: DateTime(2026, 6, 1),
        notifyAt: DateTime(2026, 5, 31, 23, 55),
      );
      expect(r.channelName, 'ESPN');
      expect(r.programName, 'Game');
    });
  });

  group('ToastType', () {
    test('has info value', () {
      expect(ToastType.info, isNotNull);
    });
    test('has success value', () {
      expect(ToastType.success, isNotNull);
    });
    test('has warning value', () {
      expect(ToastType.warning, isNotNull);
    });
    test('has error value', () {
      expect(ToastType.error, isNotNull);
    });
    test('has 4 values', () {
      expect(ToastType.values.length, 4);
    });
  });
}
