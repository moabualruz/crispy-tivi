// Tests for JellyfinLoginScreen (FE-JF-02, FE-JF-03, JF-FE-01).
//
// Source: lib/features/media_servers/jellyfin/presentation/screens/
//         jellyfin_login_screen.dart
//
// These tests assert EXPECTED correct behaviour from the spec. A test
// failure means the app does not match the spec — NOT that the assertion
// should be weakened.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/playlist_sync_service.dart';
import 'package:crispy_tivi/features/media_servers/jellyfin/presentation/screens/jellyfin_login_screen.dart';
import 'package:crispy_tivi/features/media_servers/jellyfin/presentation/screens/jellyfin_quick_connect_screen.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/providers/public_users_provider.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── No-op sync service ────────────────────────────────────────────────────

class _NoOpSyncService extends PlaylistSyncService {
  _NoOpSyncService(super.ref);

  @override
  Future<SyncReport> syncSource(PlaylistSource source) async =>
      const SyncReport(channelsCount: 42, vodCount: 7);

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

// ── User fixtures ─────────────────────────────────────────────────────────

MediaServerUser _user({required String name, String id = 'u1'}) =>
    MediaServerUser(id: id, name: name);

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Screen scaffold (FE-JF-03) ───────────────────────────────────────────

  group('Screen scaffold', () {
    testWidgets('AppBar title is "Connect Jellyfin"', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const JellyfinLoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connect Jellyfin'), findsOneWidget);
      });
    });

    testWidgets('Server URL, Username, and Password fields are present', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const JellyfinLoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Server URL'), findsOneWidget);
        expect(find.text('Username'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });
    });
  });

  // ── Public user picker (FE-JF-02) ────────────────────────────────────────

  group('Public user picker (FE-JF-02)', () {
    testWidgets(
      'user tiles rendered with usernames when provider returns data',
      (tester) async {
        const serverUrl = 'http://192.168.1.1:8096';

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                crispyBackendProvider.overrideWithValue(MemoryBackend()),
                mediaServerPublicUsersProvider(serverUrl).overrideWith(
                  (_) async => [
                    _user(name: 'Alice', id: 'u1'),
                    _user(name: 'Bob', id: 'u2'),
                  ],
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const JellyfinLoginScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Enter the URL so _resolvedUrl becomes non-empty.
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Server URL'),
            serverUrl,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pumpAndSettle();

          expect(find.text('Alice'), findsOneWidget);
          expect(find.text('Bob'), findsOneWidget);
        });
      },
    );

    testWidgets('tapping a user tile auto-fills the username field', (
      tester,
    ) async {
      const serverUrl = 'http://192.168.1.1:8096';

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
              mediaServerPublicUsersProvider(
                serverUrl,
              ).overrideWith((_) async => [_user(name: 'TapMe', id: 'u3')]),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const JellyfinLoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Server URL'),
          serverUrl,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Tap the user avatar tile by its username label.
        expect(find.text('TapMe'), findsOneWidget);
        await tester.tap(find.text('TapMe'));
        await tester.pumpAndSettle();

        // Username field should now contain 'TapMe'.
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

  // ── Quick Connect navigation (JF-FE-01) ──────────────────────────────────

  group('Quick Connect navigation (JF-FE-01)', () {
    testWidgets('"Use Quick Connect" button is absent before URL is entered', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const JellyfinLoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Use Quick Connect'), findsNothing);
      });
    });

    testWidgets(
      'navigating to JellyfinQuickConnectScreen shows correct AppBar',
      (tester) async {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                crispyBackendProvider.overrideWithValue(MemoryBackend()),
                playlistSyncServiceProvider.overrideWith(
                  (ref) => _NoOpSyncService(ref),
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder:
                      (ctx) => Scaffold(
                        body: TextButton(
                          onPressed:
                              () => Navigator.of(ctx).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => const JellyfinQuickConnectScreen(
                                        serverUrl: 'http://192.168.1.1:8096',
                                      ),
                                ),
                              ),
                          child: const Text('Go to QC'),
                        ),
                      ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Go to QC'));
          await tester.pumpAndSettle();

          expect(find.byType(JellyfinQuickConnectScreen), findsOneWidget);
          expect(find.text('Jellyfin Quick Connect'), findsOneWidget);

          // Drain Dio's internal connect-timeout timer so it does not
          // outlive the widget tree disposal and cause a pending-timer
          // test failure.
          await tester.pump(const Duration(seconds: 2));
        });
      },
    );
  });

  // ── Form validation ───────────────────────────────────────────────────────

  group('Form validation', () {
    testWidgets('empty URL and credential fields show "Required" errors', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const JellyfinLoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(find.text('Required'), findsAtLeastNWidgets(1));
      });
    });
  });

  // ── SyncProgressDialog on successful auth ────────────────────────────────

  group('SyncProgressDialog shown on successful auth', () {
    testWidgets('Connect with valid credentials triggers SyncProgressDialog', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crispyBackendProvider.overrideWithValue(MemoryBackend()),
              playlistSyncServiceProvider.overrideWith(
                (ref) => _NoOpSyncService(ref),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaServerLoginScreen(
                serverName: 'Jellyfin',
                authenticate: _stubAuthenticate,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Server URL'),
          'http://192.168.1.1:8096',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Username'),
          'admin',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'secret',
        );

        await tester.tap(find.text('Connect'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Check before pumpAndSettle — the auto-dismiss timer (1500ms)
        // would close the dialog during settling.
        final hasSyncing =
            find.text('Syncing libraries…').evaluate().isNotEmpty;
        final hasDone = find.text('Sync Complete').evaluate().isNotEmpty;
        expect(hasSyncing || hasDone, isTrue);

        // Let the auto-dismiss timer complete.
        await tester.pumpAndSettle();
      });
    });
  });
}

// ── Stub authenticate callback ────────────────────────────────────────────

Future<PlaylistSource> _stubAuthenticate(
  Dio dio,
  String url,
  String username,
  String password,
) async {
  return PlaylistSource(
    id: 'test-jf-1',
    name: 'Test Jellyfin',
    url: url,
    type: PlaylistSourceType.jellyfin,
    username: username,
    accessToken: 'fake-token',
    deviceId: 'test-device',
  );
}
