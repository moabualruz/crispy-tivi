import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/transfer_task.dart';

void main() {
  group('TransferDirection', () {
    test('has exactly two values', () {
      expect(TransferDirection.values.length, 2);
    });

    test('contains upload and download', () {
      expect(
        TransferDirection.values,
        containsAll([TransferDirection.upload, TransferDirection.download]),
      );
    });
  });

  group('TransferStatus', () {
    test('has exactly five values', () {
      expect(TransferStatus.values.length, 5);
    });

    test('contains all expected statuses', () {
      expect(
        TransferStatus.values,
        containsAll([
          TransferStatus.queued,
          TransferStatus.active,
          TransferStatus.paused,
          TransferStatus.completed,
          TransferStatus.failed,
        ]),
      );
    });
  });

  group('TransferTask', () {
    final now = DateTime(2026, 2, 20, 12, 0);

    TransferTask createSubject({
      String id = 'task-1',
      String recordingId = 'rec-1',
      String backendId = 'backend-1',
      TransferDirection direction = TransferDirection.upload,
      TransferStatus status = TransferStatus.queued,
      int totalBytes = 1000,
      int transferredBytes = 0,
      DateTime? createdAt,
      String? errorMessage,
      String? remotePath,
    }) {
      return TransferTask(
        id: id,
        recordingId: recordingId,
        backendId: backendId,
        direction: direction,
        status: status,
        totalBytes: totalBytes,
        transferredBytes: transferredBytes,
        createdAt: createdAt ?? now,
        errorMessage: errorMessage,
        remotePath: remotePath,
      );
    }

    group('constructor', () {
      test('creates with required fields', () {
        final task = TransferTask(
          id: 't1',
          recordingId: 'r1',
          backendId: 'b1',
          direction: TransferDirection.upload,
          status: TransferStatus.queued,
          createdAt: now,
        );

        expect(task.id, 't1');
        expect(task.recordingId, 'r1');
        expect(task.backendId, 'b1');
        expect(task.direction, TransferDirection.upload);
        expect(task.status, TransferStatus.queued);
        expect(task.createdAt, now);
        expect(task.totalBytes, 0);
        expect(task.transferredBytes, 0);
        expect(task.errorMessage, isNull);
        expect(task.remotePath, isNull);
      });

      test('creates with all fields', () {
        final task = createSubject(
          totalBytes: 5000,
          transferredBytes: 2500,
          errorMessage: 'timeout',
          remotePath: '/recordings/show.ts',
        );

        expect(task.totalBytes, 5000);
        expect(task.transferredBytes, 2500);
        expect(task.errorMessage, 'timeout');
        expect(task.remotePath, '/recordings/show.ts');
      });

      test('totalBytes defaults to 0', () {
        final task = TransferTask(
          id: 't1',
          recordingId: 'r1',
          backendId: 'b1',
          direction: TransferDirection.download,
          status: TransferStatus.active,
          createdAt: now,
        );

        expect(task.totalBytes, 0);
      });

      test('transferredBytes defaults to 0', () {
        final task = TransferTask(
          id: 't1',
          recordingId: 'r1',
          backendId: 'b1',
          direction: TransferDirection.download,
          status: TransferStatus.active,
          createdAt: now,
        );

        expect(task.transferredBytes, 0);
      });
    });

    group('progress', () {
      test('returns 0 when totalBytes is 0', () {
        final task = createSubject(totalBytes: 0);

        expect(task.progress, 0.0);
      });

      test('returns 0 when totalBytes is negative', () {
        final task = createSubject(totalBytes: -100);

        expect(task.progress, 0.0);
      });

      test('returns correct ratio', () {
        final task = createSubject(totalBytes: 1000, transferredBytes: 500);

        expect(task.progress, 0.5);
      });

      test('returns 1.0 when fully transferred', () {
        final task = createSubject(totalBytes: 1000, transferredBytes: 1000);

        expect(task.progress, 1.0);
      });

      test('clamps to 1.0 when over-transferred', () {
        final task = createSubject(totalBytes: 1000, transferredBytes: 1500);

        expect(task.progress, 1.0);
      });

      test('returns 0.0 when no bytes transferred', () {
        final task = createSubject(totalBytes: 5000, transferredBytes: 0);

        expect(task.progress, 0.0);
      });

      test('handles small fractional progress', () {
        final task = createSubject(totalBytes: 10000, transferredBytes: 1);

        expect(task.progress, closeTo(0.0001, 0.0001));
      });

      test('clamps negative transferred to 0.0', () {
        final task = createSubject(totalBytes: 1000, transferredBytes: -100);

        expect(task.progress, 0.0);
      });
    });

    group('isDone', () {
      test('returns true for completed status', () {
        final task = createSubject(status: TransferStatus.completed);

        expect(task.isDone, isTrue);
      });

      test('returns true for failed status', () {
        final task = createSubject(
          status: TransferStatus.failed,
          errorMessage: 'Connection lost',
        );

        expect(task.isDone, isTrue);
      });

      test('returns false for queued status', () {
        final task = createSubject(status: TransferStatus.queued);

        expect(task.isDone, isFalse);
      });

      test('returns false for active status', () {
        final task = createSubject(status: TransferStatus.active);

        expect(task.isDone, isFalse);
      });

      test('returns false for paused status', () {
        final task = createSubject(status: TransferStatus.paused);

        expect(task.isDone, isFalse);
      });
    });

    group('copyWith', () {
      test('returns identical when no params given', () {
        final task = createSubject(
          totalBytes: 2000,
          transferredBytes: 500,
          errorMessage: 'err',
          remotePath: '/path/file.ts',
        );
        final copy = task.copyWith();

        expect(copy.id, task.id);
        expect(copy.recordingId, task.recordingId);
        expect(copy.backendId, task.backendId);
        expect(copy.direction, task.direction);
        expect(copy.status, task.status);
        expect(copy.totalBytes, task.totalBytes);
        expect(copy.transferredBytes, task.transferredBytes);
        expect(copy.createdAt, task.createdAt);
        expect(copy.errorMessage, task.errorMessage);
        expect(copy.remotePath, task.remotePath);
      });

      test('overrides id', () {
        final task = createSubject();
        final copy = task.copyWith(id: 'new-id');

        expect(copy.id, 'new-id');
        expect(copy.recordingId, task.recordingId);
      });

      test('overrides recordingId', () {
        final task = createSubject();
        final copy = task.copyWith(recordingId: 'rec-99');

        expect(copy.recordingId, 'rec-99');
        expect(copy.id, task.id);
      });

      test('overrides backendId', () {
        final task = createSubject();
        final copy = task.copyWith(backendId: 'backend-99');

        expect(copy.backendId, 'backend-99');
      });

      test('overrides direction', () {
        final task = createSubject(direction: TransferDirection.upload);
        final copy = task.copyWith(direction: TransferDirection.download);

        expect(copy.direction, TransferDirection.download);
      });

      test('overrides status', () {
        final task = createSubject(status: TransferStatus.queued);
        final copy = task.copyWith(status: TransferStatus.active);

        expect(copy.status, TransferStatus.active);
      });

      test('overrides totalBytes', () {
        final task = createSubject(totalBytes: 1000);
        final copy = task.copyWith(totalBytes: 5000);

        expect(copy.totalBytes, 5000);
      });

      test('overrides transferredBytes', () {
        final task = createSubject(transferredBytes: 0);
        final copy = task.copyWith(transferredBytes: 750);

        expect(copy.transferredBytes, 750);
      });

      test('overrides createdAt', () {
        final task = createSubject();
        final newDate = DateTime(2026, 6, 15);
        final copy = task.copyWith(createdAt: newDate);

        expect(copy.createdAt, newDate);
      });

      test('overrides errorMessage', () {
        final task = createSubject();
        final copy = task.copyWith(errorMessage: 'network error');

        expect(copy.errorMessage, 'network error');
      });

      test('overrides remotePath', () {
        final task = createSubject();
        final copy = task.copyWith(remotePath: '/new/path.ts');

        expect(copy.remotePath, '/new/path.ts');
      });

      test('overrides multiple fields at once', () {
        final task = createSubject();
        final copy = task.copyWith(
          status: TransferStatus.active,
          transferredBytes: 500,
          totalBytes: 2000,
        );

        expect(copy.status, TransferStatus.active);
        expect(copy.transferredBytes, 500);
        expect(copy.totalBytes, 2000);
        expect(copy.id, task.id);
      });
    });

    group('equality', () {
      test('equal when ids match', () {
        final a = createSubject(id: 'same-id', status: TransferStatus.queued);
        final b = createSubject(id: 'same-id', status: TransferStatus.active);

        expect(a, equals(b));
      });

      test('not equal when ids differ', () {
        final a = createSubject(id: 'id-1');
        final b = createSubject(id: 'id-2');

        expect(a, isNot(equals(b)));
      });

      test('equal to itself (identity)', () {
        final task = createSubject();

        expect(task, equals(task));
      });

      test('not equal to object of different type', () {
        final task = createSubject();

        expect(task, isNot(equals('not a task')));
      });
    });

    group('hashCode', () {
      test('equal for same id', () {
        final a = createSubject(id: 'same-id', totalBytes: 100);
        final b = createSubject(id: 'same-id', totalBytes: 999);

        expect(a.hashCode, equals(b.hashCode));
      });

      test('typically differs for different ids', () {
        final a = createSubject(id: 'id-1');
        final b = createSubject(id: 'id-2');

        // Not guaranteed but highly likely
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });

      test('is consistent across calls', () {
        final task = createSubject();

        expect(task.hashCode, equals(task.hashCode));
      });
    });
  });
}
