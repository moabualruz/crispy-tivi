// Tests for JellyfinQuickConnectScreen (JF-FE-01, MSB-FE-04).
//
// Source: lib/features/media_servers/jellyfin/presentation/screens/
//         jellyfin_quick_connect_screen.dart
//
// Spec items verified:
//   - AppBar title "Jellyfin Quick Connect".
//   - Loading state shows CircularProgressIndicator while initiating.
//   - Error state shows "Quick Connect failed" heading + "Try again" button.
//   - "Back" button in error state pops the screen.
//   - "Try again" restarts flow (loading state reappears).
//
// NOTE: _QcState and _QcPhase are private to the screen file.
// jellyfinQuickConnectProvider is a family provider with a private return
// type (_QcState). We cannot override it with a custom return type without
// exporting those types.
//
// Strategy:
//   - Error path: mount with an unreachable server URL (127.0.0.1:19999)
//     so the notifier's POST request fails and produces an error state.
//   - Loading path: pump without pumpAndSettle to catch the in-flight state.
//   - Code-display path: skipped (requires live Jellyfin server).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/media_servers/jellyfin/presentation/screens/jellyfin_quick_connect_screen.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── No-op sync service ────────────────────────────────────────────────────

class _NoOpSyncService extends PlaylistSyncService {
  _NoOpSyncService(super.ref);

  @override
  Future<SyncReport> syncSource(PlaylistSource source) async =>
      const SyncReport(channelsCount: 10, vodCount: 3);

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

// ── Constant ──────────────────────────────────────────────────────────────

// Nothing listens on this port → Dio throws connection refused → error state.
const _kBadUrl = 'http://127.0.0.1:19999';

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Screen scaffold ───────────────────────────────────────────────────────

  group('Screen scaffold', () {
    testWidgets('AppBar title is "Jellyfin Quick Connect"', (tester) async {
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        // Pump a single frame so the Scaffold renders (provider is loading).
        await tester.pump();

        expect(find.text('Jellyfin Quick Connect'), findsOneWidget);
      });
    });

    testWidgets('Scaffold is present after render', (tester) async {
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });
    });
  });

  // ── Loading state ─────────────────────────────────────────────────────────

  group('Loading state', () {
    testWidgets('CircularProgressIndicator shown while provider is loading', (
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        // Single pump — provider is still in loading state.
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      });
    });
  });

  // ── Error state ────────────────────────────────────────────────────────────

  group('Error state (unreachable server)', () {
    testWidgets('"Quick Connect failed" heading shown after connection error', (
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Quick Connect failed'), findsOneWidget);
      });
    });

    testWidgets('"Try again" button present in error state', (tester) async {
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Try again'), findsOneWidget);
      });
    });

    testWidgets('"Back" button present in error state', (tester) async {
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Back'), findsOneWidget);
      });
    });

    testWidgets('"Back" button pops the screen', (tester) async {
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
                                      serverUrl: _kBadUrl,
                                    ),
                              ),
                            ),
                        child: const Text('Open QC'),
                      ),
                    ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open QC'));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Quick Connect failed'), findsOneWidget);

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        // After pop the root screen is back.
        expect(find.text('Open QC'), findsOneWidget);
      });
    });

    testWidgets('"Try again" restarts flow and shows loading indicator', (
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Quick Connect failed'), findsOneWidget);

        await tester.tap(find.text('Try again'));
        await tester.pump();

        // The notifier calls restart() which sets state to AsyncLoading,
        // which renders the LoadingStateWidget (CircularProgressIndicator).
        expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      });
    });
  });

  // ── Code display spec (requires live Jellyfin) ────────────────────────────

  group('Code display — polling state', () {
    testWidgets(
      '6-character code displayed in large card (requires live Jellyfin)',
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
                home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
              ),
            ),
          );
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Spec: code is exactly 6 uppercase alphanumeric characters.
          expect(
            find.textContaining(RegExp(r'^[A-Z0-9]{6}$')),
            findsOneWidget,
            reason:
                'A 6-char QC code must appear (spec JF-FE-01). '
                'Fails without live Jellyfin server.',
          );
        });
      },
      skip: true,
    );

    testWidgets(
      '"Expires in 02:00" countdown visible at session start (120 s TTL)',
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
                home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
              ),
            ),
          );
          await tester.pumpAndSettle(const Duration(seconds: 5));

          expect(
            find.text('Expires in 02:00'),
            findsOneWidget,
            reason:
                'TTL countdown must start at 02:00 (spec JF-FE-01). '
                'Fails without live Jellyfin server.',
          );
        });
      },
      skip: true,
    );

    testWidgets('"Cancel" and "New code" buttons visible in polling state', (
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
              home: const JellyfinQuickConnectScreen(serverUrl: _kBadUrl),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('New code'), findsOneWidget);
      });
    }, skip: true);
  });
}
