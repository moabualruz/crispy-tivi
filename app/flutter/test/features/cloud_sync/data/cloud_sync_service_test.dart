import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/features/cloud_sync/data/'
    'cloud_sync_service.dart';
import 'package:crispy_tivi/features/cloud_sync/data/'
    'google_auth_service.dart';
import 'package:crispy_tivi/features/cloud_sync/domain/'
    'entities/cloud_sync_state.dart';
import 'package:crispy_tivi/features/cloud_sync/domain/'
    'entities/sync_conflict.dart';
import 'package:crispy_tivi/features/settings/data/'
    'backup_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockBackupService extends Mock implements BackupService {}

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockCrispyBackend extends Mock implements CrispyBackend {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CloudSyncService service;
  late MockBackupService mockBackup;
  late MockGoogleAuthService mockAuth;
  late MockCrispyBackend mockBackend;

  setUp(() {
    mockBackup = MockBackupService();
    mockAuth = MockGoogleAuthService();
    mockBackend = MockCrispyBackend();
    service = CloudSyncService(
      backupService: mockBackup,
      authService: mockAuth,
      backend: mockBackend,
    );

    // Stub connectivity_plus method channel so
    // isOnline calls don't throw.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async {
            if (call.method == 'check') {
              return ['wifi'];
            }
            return null;
          },
        );
  });

  group('CloudSyncService', () {
    group('deviceId', () {
      test('returns a non-empty string', () {
        final id = service.deviceId;
        expect(id, isNotEmpty);
      });

      test('contains platform identifier', () {
        final id = service.deviceId;
        // On non-web, should contain OS info.
        expect(id, isNotEmpty);
        expect(id, contains('_'));
      });

      test('returns same value on repeated calls', () {
        final id1 = service.deviceId;
        final id2 = service.deviceId;
        // deviceId uses Platform.* so should be
        // deterministic within the same process.
        expect(id1, id2);
      });
    });

    group('syncNow', () {
      test('returns failure when not signed in', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        final result = await service.syncNow();

        expect(result.success, isFalse);
        expect(result.error, 'Not signed in');
      });

      test('returns failure when not signed in '
          'with conflict resolution', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        final result = await service.syncNow(
          conflictResolution: ConflictResolution.keepLocal,
        );

        expect(result.success, isFalse);
        expect(result.error, 'Not signed in');
      });

      test('checks auth before proceeding', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        await service.syncNow();

        verify(() => mockAuth.isSignedIn).called(1);
      });

      test('returns failure with CloudSyncError message', () async {
        when(() => mockAuth.isSignedIn).thenReturn(true);
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenThrow(const AuthSyncError('Token expired'));

        final result = await service.syncNow();

        // The connectivity check happens before auth
        // client check. If we can't mock Connectivity,
        // the auth error will be caught.
        expect(result.success, isFalse);
      });

      test('returns failure on generic exception', () async {
        when(() => mockAuth.isSignedIn).thenReturn(true);
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenThrow(Exception('unexpected'));

        final result = await service.syncNow();

        expect(result.success, isFalse);
      });
    });

    group('forceUpload', () {
      test('returns failure when not signed in', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        final result = await service.forceUpload();

        expect(result.success, isFalse);
        expect(result.error, 'Not signed in');
      });

      test('checks auth status before proceeding', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        await service.forceUpload();

        verify(() => mockAuth.isSignedIn).called(1);
      });

      test('returns failure on CloudSyncError', () async {
        when(() => mockAuth.isSignedIn).thenReturn(true);
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenThrow(const AuthSyncError('Auth failed'));

        final result = await service.forceUpload();

        // isOnline may fail first (no Connectivity
        // plugin in tests) or auth error is caught.
        // Either way, result should be a failure.
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('returns failure on generic error', () async {
        when(() => mockAuth.isSignedIn).thenReturn(true);
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenThrow(Exception('Boom'));

        final result = await service.forceUpload();

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('forceDownload', () {
      test('returns failure when not signed in', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        final result = await service.forceDownload();

        expect(result.success, isFalse);
        expect(result.error, 'Not signed in');
      });

      test('checks auth status', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        await service.forceDownload();

        verify(() => mockAuth.isSignedIn).called(1);
      });

      test('returns failure on CloudSyncError', () async {
        when(() => mockAuth.isSignedIn).thenReturn(true);
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenThrow(const NetworkSyncError());

        final result = await service.forceDownload();

        // isOnline may fail first (no Connectivity
        // plugin in tests) or CloudSyncError is
        // caught. Either way, result is a failure.
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('returns failure on generic exception', () async {
        when(() => mockAuth.isSignedIn).thenReturn(true);
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenThrow(Exception('network issue'));

        final result = await service.forceDownload();

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('syncIfNeeded', () {
      test('returns null when not signed in', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        final result = await service.syncIfNeeded();

        expect(result, isNull);
      });

      test('checks auth before proceeding', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        await service.syncIfNeeded();

        verify(() => mockAuth.isSignedIn).called(1);
      });

      test('returns null when not signed in even if '
          'force=true', () async {
        when(() => mockAuth.isSignedIn).thenReturn(false);

        final result = await service.syncIfNeeded(force: true);

        expect(result, isNull);
      });
    });

    group('getConflictDetails', () {
      test('returns null when auth client is null and '
          'drive client not initialized', () async {
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenAnswer((_) async => null);

        final result = await service.getConflictDetails();

        expect(result, isNull);
      });

      test('returns null on exception', () async {
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenThrow(Exception('Auth error'));

        final result = await service.getConflictDetails();

        expect(result, isNull);
      });

      test('tries to get authenticated client', () async {
        when(
          () => mockAuth.getAuthenticatedClient(),
        ).thenAnswer((_) async => null);

        await service.getConflictDetails();

        verify(() => mockAuth.getAuthenticatedClient()).called(1);
      });
    });

    group('dispose', () {
      test('can be called without error', () {
        // Should not throw.
        service.dispose();
      });

      test('can be called multiple times', () {
        service.dispose();
        service.dispose();
        // Should not throw.
      });
    });
  });

  group('SyncResult', () {
    group('SyncResult.success', () {
      test('has success=true', () {
        final result = SyncResult.success(direction: SyncDirection.upload);
        expect(result.success, isTrue);
      });

      test('stores direction', () {
        final result = SyncResult.success(direction: SyncDirection.download);
        expect(result.direction, SyncDirection.download);
      });

      test('stores itemsSynced', () {
        final result = SyncResult.success(
          direction: SyncDirection.upload,
          itemsSynced: 42,
        );
        expect(result.itemsSynced, 42);
      });

      test('defaults itemsSynced to 0', () {
        final result = SyncResult.success(direction: SyncDirection.upload);
        expect(result.itemsSynced, 0);
      });
    });

    group('SyncResult.failure', () {
      test('has success=false', () {
        final result = SyncResult.failure('test error');
        expect(result.success, isFalse);
      });

      test('stores error message', () {
        final result = SyncResult.failure('some error');
        expect(result.error, 'some error');
      });

      test('has null direction', () {
        final result = SyncResult.failure('err');
        expect(result.direction, isNull);
      });
    });

    group('SyncResult.noChange', () {
      test('has success=true', () {
        final result = SyncResult.noChange();
        expect(result.success, isTrue);
      });

      test('has direction=noChange', () {
        final result = SyncResult.noChange();
        expect(result.direction, SyncDirection.noChange);
      });

      test('has 0 items synced', () {
        final result = SyncResult.noChange();
        expect(result.itemsSynced, 0);
      });
    });
  });
}
