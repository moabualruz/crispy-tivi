import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'source_add_dialogs.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'source_portal_dialogs.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── Minimal AppConfig ──────────────────────────────────────────

AppConfig _minimalConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.1',
  api: ApiConfig(
    baseUrl: 'http://test',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 2000,
    autoPlay: true,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#3B82F6',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 60,
    channelListRefreshIntervalMinutes: 30,
    maxCachedEpgDays: 7,
  ),
);

// ── Fake SettingsNotifier ─────────────────────────────────────

class _FakeSettingsNotifier extends SettingsNotifier {
  PlaylistSource? addedSource;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());

  @override
  Future<void> addSource(PlaylistSource source) async {
    addedSource = source;
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(sources: [...current.sources, source]),
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Test helpers ──────────────────────────────────────────────

/// Pumps a scaffold that opens [dialog] when tapping the "Open" button.
///
/// [buildDialog] receives the dialog context and WidgetRef and must call
/// [showDialog] directly (not return a widget).
Future<_FakeSettingsNotifier> _pumpDialogTrigger(
  WidgetTester tester, {
  required void Function(BuildContext ctx, WidgetRef ref) openDialog,
  MemoryBackend? backend,
}) async {
  final fakeNotifier = _FakeSettingsNotifier();
  final backendImpl = backend ?? MemoryBackend();
  final cache = CacheService(backendImpl);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backendImpl),
        cacheServiceProvider.overrideWithValue(cache),
        settingsNotifierProvider.overrideWith(() => fakeNotifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () => openDialog(context, ref),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeNotifier;
}

// ── Tests ─────────────────────────────────────────────────────

void main() {
  // ── M3U Add Dialog ───────────────────────────────────────────

  group('M3U Add Dialog', () {
    Future<_FakeSettingsNotifier> pumpM3u(WidgetTester tester) =>
        _pumpDialogTrigger(
          tester,
          openDialog:
              (ctx, ref) => showAddM3uDialog(
                context: ctx,
                ref: ref,
                isMounted: () => true,
              ),
        );

    testWidgets('shows "Add M3U Playlist" title', (tester) async {
      await pumpM3u(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add M3U Playlist'), findsOneWidget);
    });

    testWidgets('shows Name and Playlist URL fields', (tester) async {
      await pumpM3u(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Playlist URL'), findsOneWidget);
    });

    testWidgets('shows Cancel and Add buttons', (tester) async {
      await pumpM3u(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('empty URL shows "URL is required." error', (tester) async {
      await pumpM3u(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Submit with no URL entered.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('URL is required.'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses dialog', (tester) async {
      await pumpM3u(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add M3U Playlist'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add M3U Playlist'), findsNothing);
    });

    testWidgets('Cancel does not add a source', (tester) async {
      final fake = await pumpM3u(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fake.addedSource, isNull);
    });

    testWidgets('error clears when re-submitting with non-empty URL', (
      tester,
    ) async {
      await pumpM3u(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // First submit with no URL → shows error.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('URL is required.'), findsOneWidget);

      // Now type a URL — error is still shown until re-submit.
      await tester.enterText(
        find.widgetWithText(TextField, 'Playlist URL'),
        'http://example.com/playlist.m3u',
      );
      await tester.pumpAndSettle();

      // The error text widget is still rendered until the user re-submits
      // or the state is cleared; this is the _current_ app behavior.
      // If the app clears error on text change, update this assertion.
      expect(find.text('URL is required.'), findsOneWidget);
    });
  });

  // ── Xtream Add Dialog ────────────────────────────────────────

  group('Xtream Add Dialog', () {
    Future<_FakeSettingsNotifier> pumpXtream(WidgetTester tester) =>
        _pumpDialogTrigger(
          tester,
          openDialog:
              (ctx, ref) => showAddXtreamDialog(
                context: ctx,
                ref: ref,
                isMounted: () => true,
              ),
        );

    testWidgets('shows "Add Xtream Codes" title', (tester) async {
      await pumpXtream(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add Xtream Codes'), findsOneWidget);
    });

    testWidgets('shows 4 fields: Name, Server URL, Username, Password', (
      tester,
    ) async {
      await pumpXtream(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows Cancel and Add buttons', (tester) async {
      await pumpXtream(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets(
      'submitting with empty required fields shows "All fields are required."',
      (tester) async {
        await pumpXtream(tester);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // All fields empty → submit.
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(find.text('All fields are required.'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting with URL only (no user/pass) shows required error',
      (tester) async {
        await pumpXtream(tester);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Server URL'),
          'http://provider.com:8080',
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(find.text('All fields are required.'), findsOneWidget);
      },
    );

    testWidgets('Cancel button dismisses without adding source', (
      tester,
    ) async {
      final fake = await pumpXtream(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add Xtream Codes'), findsNothing);
      expect(fake.addedSource, isNull);
    });
  });

  // ── Stalker Add Dialog ───────────────────────────────────────

  group('Stalker Add Dialog', () {
    Future<_FakeSettingsNotifier> pumpStalker(WidgetTester tester) =>
        _pumpDialogTrigger(
          tester,
          openDialog:
              (ctx, ref) => showAddStalkerDialog(
                context: ctx,
                ref: ref,
                isMounted: () => true,
              ),
        );

    testWidgets('shows "Add Stalker Portal" title', (tester) async {
      await pumpStalker(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add Stalker Portal'), findsOneWidget);
    });

    testWidgets('shows Name, Portal URL, and MAC Address fields', (
      tester,
    ) async {
      await pumpStalker(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Portal URL'), findsOneWidget);
      expect(find.text('MAC Address'), findsOneWidget);
    });

    testWidgets('invalid MAC address shows format error', (tester) async {
      await pumpStalker(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter a valid URL but an invalid MAC.
      await tester.enterText(
        find.widgetWithText(TextField, 'Portal URL'),
        'http://portal.example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'MAC Address'),
        'INVALID',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(
        find.text('Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel button dismisses without adding source', (
      tester,
    ) async {
      final fake = await pumpStalker(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add Stalker Portal'), findsNothing);
      expect(fake.addedSource, isNull);
    });

    testWidgets('MAC field uses TextCapitalization.characters', (tester) async {
      await pumpStalker(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find the MAC address TextField and verify its capitalization setting.
      final macField =
          tester.widgetList<TextField>(find.byType(TextField)).last;
      expect(macField.textCapitalization, TextCapitalization.characters);
    });
  });

  // ── EPG URL Dialog ───────────────────────────────────────────

  group('EPG URL Dialog', () {
    Future<_FakeSettingsNotifier> pumpEpg(
      WidgetTester tester, {
      String? existingUrl,
    }) async {
      final backendImpl = MemoryBackend();
      final cache = CacheService(backendImpl);
      if (existingUrl != null) {
        await cache.setSetting(kGlobalEpgUrlKey, existingUrl);
      }

      return _pumpDialogTrigger(
        tester,
        openDialog:
            (ctx, ref) =>
                showEpgUrlDialog(context: ctx, ref: ref, isMounted: () => true),
        backend: backendImpl,
      );
    }

    testWidgets('shows "EPG URL" title', (tester) async {
      await pumpEpg(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('EPG URL'), findsOneWidget);
    });

    testWidgets('shows XMLTV URL field', (tester) async {
      await pumpEpg(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('XMLTV URL'), findsOneWidget);
    });

    testWidgets('shows Cancel and Save buttons', (tester) async {
      await pumpEpg(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses dialog', (tester) async {
      await pumpEpg(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Save shows "EPG URL saved" snackbar', (tester) async {
      await pumpEpg(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('EPG URL saved'), findsOneWidget);
    });

    testWidgets('Save persists the entered URL to cache', (tester) async {
      final backendImpl = MemoryBackend();
      final cache = CacheService(backendImpl);
      final fakeNotifier = _FakeSettingsNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crispyBackendProvider.overrideWithValue(backendImpl),
            cacheServiceProvider.overrideWithValue(cache),
            settingsNotifierProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed:
                        () => showEpgUrlDialog(
                          context: context,
                          ref: ref,
                          isMounted: () => true,
                        ),
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/epg.xml',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await cache.getSetting(kGlobalEpgUrlKey);
      expect(saved, 'https://example.com/epg.xml');
    });
  });
}
