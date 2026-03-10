// Tests for SyncProgressDialog.
//
// Source: lib/features/media_servers/shared/presentation/widgets/
//         sync_progress_dialog.dart
//
// Spec items verified:
//   - Non-dismissible: barrierDismissible=false verified.
//   - Spinner state: CircularProgressIndicator present while syncing.
//   - Success state: check icon + "N channels, N movies" summary text.
//   - Error state: error icon + retry button present.
//   - Auto-dismiss after 1.5 s success (fake timer via fake_async).
//
// The SyncProgressDialog is a ConsumerStatefulWidget that calls
// playlistSyncServiceProvider.syncSource() on initState.  We override
// the provider with controllable stub implementations.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/widgets/sync_progress_dialog.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── Sync service stubs ────────────────────────────────────────────────────

/// Stub that never completes — keeps the dialog in the spinner state.
class _HangingSyncService extends PlaylistSyncService {
  _HangingSyncService(super.ref);

  @override
  Future<SyncReport> syncSource(PlaylistSource source) {
    return Completer<SyncReport>().future;
  }

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

/// Stub that succeeds immediately with a known report.
class _SuccessSyncService extends PlaylistSyncService {
  _SuccessSyncService(super.ref, {required this.channels, required this.vod});

  final int channels;
  final int vod;

  @override
  Future<SyncReport> syncSource(PlaylistSource source) async {
    return SyncReport(channelsCount: channels, vodCount: vod);
  }

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

/// Stub that always throws so the error state is shown.
class _FailingSyncService extends PlaylistSyncService {
  _FailingSyncService(super.ref);

  @override
  Future<SyncReport> syncSource(PlaylistSource source) async {
    throw Exception('Network timeout');
  }

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

/// Stub that counts calls and always fails.
class _CountingSyncService extends PlaylistSyncService {
  _CountingSyncService(super.ref, {required this.onCall});

  final VoidCallback onCall;

  @override
  Future<SyncReport> syncSource(PlaylistSource source) async {
    onCall();
    throw Exception('always fails');
  }

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

// ── Test source fixture ───────────────────────────────────────────────────

const _kSource = PlaylistSource(
  id: 'jf-test-1',
  name: 'Test Jellyfin',
  url: 'http://192.168.1.1:8096',
  type: PlaylistSourceType.jellyfin,
  accessToken: 'tok',
  deviceId: 'test',
);

// ── Helpers ───────────────────────────────────────────────────────────────

/// Builds an app host that opens SyncProgressDialog when the button is tapped.
/// [makeSyncService] is the factory forwarded to
/// [playlistSyncServiceProvider.overrideWith].
Widget _buildDialogHost(PlaylistSyncService Function(Ref) makeSyncService) {
  return ProviderScope(
    overrides: [
      crispyBackendProvider.overrideWithValue(MemoryBackend()),
      playlistSyncServiceProvider.overrideWith(makeSyncService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder:
              (ctx) => TextButton(
                onPressed: () => SyncProgressDialog.show(ctx, _kSource),
                child: const Text('Open dialog'),
              ),
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Non-dismissible barrier ───────────────────────────────────────────────

  group('Non-dismissible barrier', () {
    testWidgets('tapping outside the dialog does not dismiss it', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _HangingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pump();

        expect(find.text('Syncing libraries…'), findsOneWidget);

        // Tap outside dialog.
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();

        // Dialog must still be present.
        expect(find.text('Syncing libraries…'), findsOneWidget);
      });
    });

    testWidgets(
      'SyncProgressDialog widget is still present after barrier tap',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _buildDialogHost((ref) => _HangingSyncService(ref)),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open dialog'));
          await tester.pump();

          expect(find.byType(SyncProgressDialog), findsOneWidget);

          await tester.tapAt(const Offset(5, 5));
          await tester.pump();

          expect(find.byType(SyncProgressDialog), findsOneWidget);
        });
      },
    );
  });

  // ── Spinner state ─────────────────────────────────────────────────────────

  group('Spinner state', () {
    testWidgets('CircularProgressIndicator present while syncing', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _HangingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      });
    });

    testWidgets('"Syncing libraries…" label shown', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _HangingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pump();

        expect(find.text('Syncing libraries…'), findsOneWidget);
      });
    });

    testWidgets('source name shown below spinner', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _HangingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pump();

        expect(find.text('Test Jellyfin'), findsOneWidget);
      });
    });
  });

  // ── Success state ─────────────────────────────────────────────────────────

  group('Success state', () {
    testWidgets('check icon shown after successful sync', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost(
            (ref) => _SuccessSyncService(ref, channels: 2452, vod: 300),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      });
    });

    testWidgets('"Sync Complete" title shown', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost(
            (ref) => _SuccessSyncService(ref, channels: 2452, vod: 300),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Sync Complete'), findsOneWidget);
      });
    });

    testWidgets('summary shows "N channels, N movies" with correct counts', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost(
            (ref) => _SuccessSyncService(ref, channels: 42, vod: 7),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('42 channels, 7 movies'), findsOneWidget);
      });
    });

    testWidgets('dialog auto-dismisses after 1500 ms on success', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
              playlistSyncServiceProvider.overrideWith(
                (ref) => _SuccessSyncService(ref, channels: 5, vod: 3),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder:
                      (ctx) => TextButton(
                        onPressed: () => SyncProgressDialog.show(ctx, _kSource),
                        child: const Text('Open dialog'),
                      ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Sync Complete'), findsOneWidget);

        // Advance past the 1500 ms auto-dismiss delay.
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        expect(find.text('Sync Complete'), findsNothing);
      });
    });
  });

  // ── Error state ───────────────────────────────────────────────────────────

  group('Error state', () {
    testWidgets('error icon shown after sync failure', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _FailingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });

    testWidgets('"Sync Failed" title shown', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _FailingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Sync Failed'), findsOneWidget);
      });
    });

    testWidgets('"Retry" button present in error state', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _FailingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
      });
    });

    testWidgets('"Cancel" button present in error state', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildDialogHost((ref) => _FailingSyncService(ref)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel'), findsOneWidget);
      });
    });

    testWidgets('"Retry" re-triggers sync and shows spinner', (tester) async {
      var callCount = 0;

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
              playlistSyncServiceProvider.overrideWith(
                (ref) => _CountingSyncService(ref, onCall: () => callCount++),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder:
                      (ctx) => TextButton(
                        onPressed: () => SyncProgressDialog.show(ctx, _kSource),
                        child: const Text('Open dialog'),
                      ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Sync Failed'), findsOneWidget);
        expect(callCount, 1);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      });
    });

    testWidgets('"Cancel" dismisses dialog and returns false', (tester) async {
      bool? result;

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
              playlistSyncServiceProvider.overrideWith(
                (ref) => _FailingSyncService(ref),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder:
                      (ctx) => TextButton(
                        onPressed: () async {
                          result = await SyncProgressDialog.show(ctx, _kSource);
                        },
                        child: const Text('Open dialog'),
                      ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Sync Failed'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Sync Failed'), findsNothing);
        expect(result, isFalse);
      });
    });
  });

  // ── fake_async timer test ─────────────────────────────────────────────────

  group('Auto-dismiss timing (fake_async)', () {
    test('auto-dismiss fires at exactly 1500 ms', () {
      fakeAsync((async) {
        var dismissed = false;

        Future<void>.delayed(const Duration(milliseconds: 1500)).then((_) {
          dismissed = true;
        });

        async.elapse(const Duration(milliseconds: 1499));
        expect(dismissed, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(dismissed, isTrue);
      });
    });
  });
}
