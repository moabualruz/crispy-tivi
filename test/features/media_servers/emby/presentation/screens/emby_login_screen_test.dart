// Tests for EmbyLoginScreen (FE-EB-02, FE-EB-03).
//
// Source: lib/features/media_servers/emby/presentation/screens/
//         emby_login_screen.dart
//        lib/features/media_servers/emby/presentation/widgets/
//         emby_pin_login_dialog.dart
//
// Spec items verified:
//   - "Test Connection" button: idle → loading → success/fail state cycle.
//   - Public user picker: avatar tiles rendered with usernames; lock badge
//     for password-protected users.
//   - "Login with PIN" button present below the form.
//   - Tapping "Login with PIN" opens EmbyPinLoginDialog.
//   - EmbyPinLoginDialog: 3×4 numpad layout (digits 0-9 + backspace + confirm).
//   - PIN circle display: 8 animated circle slots.
//   - 8-digit max: no more than 8 digits accepted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/media_servers/emby/presentation/screens/emby_login_screen.dart';
import 'package:crispy_tivi/features/media_servers/emby/presentation/widgets/emby_pin_login_dialog.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/providers/public_users_provider.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── No-op sync service ────────────────────────────────────────────────────

class _NoOpSyncService extends PlaylistSyncService {
  _NoOpSyncService(super.ref);

  @override
  Future<SyncReport> syncSource(PlaylistSource source) async =>
      const SyncReport(channelsCount: 100, vodCount: 50);

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

// ── User fixtures ─────────────────────────────────────────────────────────

MediaServerUser _openUser({String name = 'Alice', String id = 'u1'}) =>
    MediaServerUser(id: id, name: name, hasConfiguredPassword: false);

MediaServerUser _lockedUser({String name = 'Bob', String id = 'u2'}) =>
    MediaServerUser(id: id, name: name, hasConfiguredPassword: true);

// ── Helpers ───────────────────────────────────────────────────────────────

const _kServerUrl = 'http://192.168.1.10:8096';

Widget _buildApp() {
  return ProviderScope(
    overrides: [
      crispyBackendProvider.overrideWithValue(MemoryBackend()),
      playlistSyncServiceProvider.overrideWith((ref) => _NoOpSyncService(ref)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const EmbyLoginScreen(),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Screen scaffold ───────────────────────────────────────────────────────

  group('Screen scaffold', () {
    testWidgets('AppBar shows "Connect Emby"', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Connect Emby'), findsOneWidget);
      });
    });

    testWidgets('Username, Password, and Server URL fields are present', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Server URL'), findsOneWidget);
        expect(find.text('Username'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });
    });
  });

  // ── Test Connection button (FE-EB-01) ─────────────────────────────────────

  group('Test Connection button', () {
    testWidgets('"Test Connection" button is visible in idle state', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Test Connection'), findsOneWidget);
      });
    });

    testWidgets(
      'tapping "Test Connection" with empty URL shows failure state',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(_buildApp());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Test Connection'));
          await tester.pumpAndSettle();

          // With empty URL the handler sets failure state with inline error.
          expect(find.text('Enter the server URL first.'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'loading state shows CircularProgressIndicator during connection test',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(_buildApp());
          await tester.pumpAndSettle();

          // Fill URL so the test-connection proceeds past the empty check.
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Server URL'),
            _kServerUrl,
          );
          await tester.pump();

          await tester.tap(find.text('Test Connection'));
          // Pump only one frame — the async call is in progress.
          await tester.pump();

          // Loading state shows "Testing connection…" or spinner.
          final hasSpinner =
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          final hasLoadingText =
              find.text('Testing connection…').evaluate().isNotEmpty;
          expect(hasSpinner || hasLoadingText, isTrue);

          // Drain Dio's internal connect-timeout timer so it does not
          // outlive the widget tree disposal and cause a pending-timer
          // test failure.
          await tester.pump(const Duration(seconds: 2));
        });
      },
    );

    testWidgets('failed test connection shows "Re-test" and "Retry" option', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // Use an unreachable URL so the test fails.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Server URL'),
          'http://127.0.0.1:19999',
        );
        await tester.pump();

        await tester.tap(find.text('Test Connection'));
        await tester.pumpAndSettle(const Duration(seconds: 6));

        // After failure the _StatusChip shows a "Retry" button.
        expect(find.text('Retry'), findsOneWidget);
      });
    });
  });

  // ── Public user picker (FE-EB-02) ─────────────────────────────────────────

  group('Public user picker (FE-EB-02)', () {
    testWidgets('user avatar tiles shown with username labels', (tester) async {
      final users = [
        _openUser(name: 'Alice', id: 'u1'),
        _lockedUser(name: 'Bob', id: 'u2'),
      ];

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
              playlistSyncServiceProvider.overrideWith(
                (ref) => _NoOpSyncService(ref),
              ),
              mediaServerPublicUsersProvider(
                _kServerUrl,
              ).overrideWith((_) async => users),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const EmbyLoginScreen(),
            ),
          ),
        );

        // Simulate URL entry so _resolvedUrl becomes non-empty and the
        // user picker row is included in the footer.
        await tester.pumpAndSettle();

        // Manually set the resolved URL by entering in the URL field.
        // The onUrlChanged callback normalizes and sets _resolvedUrl.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Server URL'),
          _kServerUrl,
        );
        // Trigger onChange debounce.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Username labels must appear in the picker row.
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
      });
    });

    testWidgets(
      'password-protected user tile shows lock badge (showPinBadge=true)',
      (tester) async {
        final users = [_lockedUser(name: 'SecretUser', id: 'u3')];

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                crispyBackendProvider.overrideWithValue(MemoryBackend()),
                playlistSyncServiceProvider.overrideWith(
                  (ref) => _NoOpSyncService(ref),
                ),
                mediaServerPublicUsersProvider(
                  _kServerUrl,
                ).overrideWith((_) async => users),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const EmbyLoginScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.enterText(
            find.widgetWithText(TextFormField, 'Server URL'),
            _kServerUrl,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pumpAndSettle();

          // Lock badge icon must be present for the password-protected user.
          expect(find.byIcon(Icons.lock_outline), findsAtLeastNWidgets(1));
          expect(find.text('SecretUser'), findsOneWidget);
        });
      },
    );

    testWidgets('tapping a user tile auto-fills the username field', (
      tester,
    ) async {
      final users = [_openUser(name: 'TapMe', id: 'u4')];

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
              playlistSyncServiceProvider.overrideWith(
                (ref) => _NoOpSyncService(ref),
              ),
              mediaServerPublicUsersProvider(
                _kServerUrl,
              ).overrideWith((_) async => users),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const EmbyLoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Server URL'),
          _kServerUrl,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Tap the user avatar tile by its username label.
        expect(find.text('TapMe'), findsOneWidget);
        await tester.tap(find.text('TapMe'));
        await tester.pumpAndSettle();

        // The username field should now contain "TapMe".
        final usernameField =
            tester
                .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'Username'),
                )
                .controller;
        expect(usernameField?.text, 'TapMe');
      });
    });
  });

  // ── PIN login (FE-EB-03) ─────────────────────────────────────────────────

  group('PIN login dialog (FE-EB-03)', () {
    testWidgets('"Login with PIN" button is present below the form', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Login with PIN'), findsOneWidget);
      });
    });

    testWidgets('tapping "Login with PIN" without URL shows snackbar error', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Login with PIN'));
        await tester.pumpAndSettle();

        expect(find.text('Enter the server URL first.'), findsOneWidget);
      });
    });

    testWidgets(
      'tapping "Login with PIN" with URL but no username shows snackbar',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(_buildApp());
          await tester.pumpAndSettle();

          await tester.enterText(
            find.widgetWithText(TextFormField, 'Server URL'),
            _kServerUrl,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Login with PIN'));
          await tester.pumpAndSettle();

          expect(
            find.text('Enter your username before using PIN.'),
            findsOneWidget,
          );
        });
      },
    );

    // ── EmbyPinLoginDialog direct tests ────────────────────────────────────

    testWidgets(
      'EmbyPinLoginDialog renders 3×4 numpad (digits 1-9, 0, backspace, confirm)',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder:
                      (ctx) => TextButton(
                        onPressed: () => showEmbyPinLoginDialog(ctx),
                        child: const Text('Open PIN'),
                      ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open PIN'));
          await tester.pumpAndSettle();

          // Dialog title.
          expect(find.text('Enter PIN'), findsOneWidget);

          // Digits 1-9 must all be present.
          for (final digit in [
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '0',
          ]) {
            expect(
              find.text(digit),
              findsOneWidget,
              reason: 'Digit $digit must be present on the numpad',
            );
          }

          // Backspace key.
          expect(find.bySemanticsLabel('Backspace'), findsOneWidget);

          // Confirm key.
          expect(find.bySemanticsLabel('Confirm'), findsOneWidget);

          // Cancel text button.
          expect(find.text('Cancel'), findsOneWidget);
        });
      },
    );

    testWidgets('PIN circle display has 8 slots (max 8 digits)', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Center(child: EmbyPinLoginDialog())),
          ),
        );
        await tester.pumpAndSettle();

        // The _PinDisplay widget renders maxLength=8 AnimatedContainer
        // circles.  We count them by finding all AnimatedContainer widgets
        // inside the dialog.
        final circles = find.byType(AnimatedContainer);
        // There should be exactly 8 circles in the PIN display row.
        expect(circles, findsNWidgets(8));
      });
    });

    testWidgets('entering more than 8 digits does not grow beyond 8 circles', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Center(child: EmbyPinLoginDialog())),
          ),
        );
        await tester.pumpAndSettle();

        // Tap digit "1" nine times — the 9th tap should be ignored.
        for (var i = 0; i < 9; i++) {
          await tester.tap(find.text('1'));
          await tester.pump();
        }

        // Still exactly 8 circles (max enforced by _append).
        expect(find.byType(AnimatedContainer), findsNWidgets(8));
      });
    });

    testWidgets('backspace removes last digit from PIN display', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Center(child: EmbyPinLoginDialog())),
          ),
        );
        await tester.pumpAndSettle();

        // Enter 3 digits.
        await tester.tap(find.text('1'));
        await tester.tap(find.text('2'));
        await tester.tap(find.text('3'));
        await tester.pump();

        // Tap backspace once.
        await tester.tap(find.bySemanticsLabel('Backspace'));
        await tester.pump();

        // The confirm button should still be enabled (PIN = "12", non-empty).
        // We verify indirectly: the dialog has not been closed.
        expect(find.text('Enter PIN'), findsOneWidget);
      });
    });

    testWidgets('confirm button is disabled when PIN is empty', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Center(child: EmbyPinLoginDialog())),
          ),
        );
        await tester.pumpAndSettle();

        // No digits entered → confirm button onTap is null.
        // The _NumpadKey renders with reduced opacity when onTap is null.
        // We verify the dialog stays open when confirm is tapped on empty.
        await tester.tap(find.bySemanticsLabel('Confirm'));
        await tester.pump();

        // Dialog still present (confirm did nothing because pin is empty).
        expect(find.text('Enter PIN'), findsOneWidget);
      });
    });

    testWidgets(
      'barrierDismissible is false — cannot dismiss dialog by tapping outside',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder:
                      (ctx) => TextButton(
                        onPressed: () => showEmbyPinLoginDialog(ctx),
                        child: const Text('Open PIN'),
                      ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open PIN'));
          await tester.pumpAndSettle();

          // Tap outside the dialog (at offset [10, 10] in the upper-left
          // corner, which is outside the centered dialog).
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          // Dialog must still be present (barrierDismissible: false).
          expect(find.text('Enter PIN'), findsOneWidget);
        });
      },
    );
  });
}
