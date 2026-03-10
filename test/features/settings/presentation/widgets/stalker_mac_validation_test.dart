import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'source_form_fields.dart';
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

// ── Fake SettingsNotifier ──────────────────────────────────────

class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  PlaylistSource? addedSource;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());

  @override
  Future<void> addSource(PlaylistSource source) async {
    addedSource = source;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── kMacAddressRegExp unit tests ───────────────────────────────

void main() {
  // ── MAC regex unit tests ─────────────────────────────────────

  group('kMacAddressRegExp', () {
    test('valid uppercase MAC passes', () {
      expect(kMacAddressRegExp.hasMatch('AA:BB:CC:DD:EE:FF'), isTrue);
    });

    test('valid lowercase MAC passes', () {
      // The regex is case-insensitive; lowercase is accepted.
      expect(kMacAddressRegExp.hasMatch('aa:bb:cc:dd:ee:ff'), isTrue);
    });

    test('mixed case MAC passes', () {
      expect(kMacAddressRegExp.hasMatch('AA:bb:CC:dd:EE:ff'), isTrue);
    });

    test('valid all-zeros MAC passes', () {
      expect(kMacAddressRegExp.hasMatch('00:00:00:00:00:00'), isTrue);
    });

    test('too few octets is invalid', () {
      expect(kMacAddressRegExp.hasMatch('AA:BB:CC'), isFalse);
    });

    test('too many octets is invalid', () {
      expect(kMacAddressRegExp.hasMatch('AA:BB:CC:DD:EE:FF:00'), isFalse);
    });

    test('dash separator is invalid (only colon allowed)', () {
      expect(kMacAddressRegExp.hasMatch('AA-BB-CC-DD-EE-FF'), isFalse);
    });

    test('no separator is invalid', () {
      expect(kMacAddressRegExp.hasMatch('AABBCCDDEEFF'), isFalse);
    });

    test('non-hex characters are invalid', () {
      expect(kMacAddressRegExp.hasMatch('GG:HH:II:JJ:KK:LL'), isFalse);
    });

    test('partial octet (1 hex digit) is invalid', () {
      expect(kMacAddressRegExp.hasMatch('A:BB:CC:DD:EE:FF'), isFalse);
    });

    test('space-separated is invalid', () {
      expect(kMacAddressRegExp.hasMatch('AA BB CC DD EE FF'), isFalse);
    });

    test('empty string is invalid', () {
      expect(kMacAddressRegExp.hasMatch(''), isFalse);
    });
  });

  // ── Stalker dialog MAC validation behavior ───────────────────

  group('Stalker dialog MAC validation', () {
    /// Pumps the Add Stalker Portal dialog and enters the given MAC address,
    /// then taps Add to trigger validation.
    Future<void> pumpAndSubmit(WidgetTester tester, String macInput) async {
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
                        () => showAddStalkerDialog(
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

      // Enter a valid Portal URL so the URL check passes.
      await tester.enterText(
        find.widgetWithText(TextField, 'Portal URL'),
        'http://portal.example.com',
      );
      // Enter the MAC address to test.
      await tester.enterText(
        find.widgetWithText(TextField, 'MAC Address'),
        macInput,
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    testWidgets('valid MAC "AA:BB:CC:DD:EE:FF" passes validation', (
      tester,
    ) async {
      await pumpAndSubmit(tester, 'AA:BB:CC:DD:EE:FF');

      // A valid MAC should not show the format error.
      // (It proceeds to network verification which will fail in tests,
      // but that's a different error message.)
      expect(
        find.text('Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.'),
        findsNothing,
      );
    });

    testWidgets('too few octets "AA:BB:CC" shows format error', (tester) async {
      await pumpAndSubmit(tester, 'AA:BB:CC');

      expect(
        find.text('Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.'),
        findsOneWidget,
      );
    });

    testWidgets('dash separator "AA-BB-CC-DD-EE-FF" shows format error', (
      tester,
    ) async {
      await pumpAndSubmit(tester, 'AA-BB-CC-DD-EE-FF');

      expect(
        find.text('Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.'),
        findsOneWidget,
      );
    });

    testWidgets('non-hex characters "GG:HH:II:JJ:KK:LL" shows format error', (
      tester,
    ) async {
      await pumpAndSubmit(tester, 'GG:HH:II:JJ:KK:LL');

      expect(
        find.text('Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.'),
        findsOneWidget,
      );
    });
  });

  // ── MAC auto-uppercase ───────────────────────────────────────

  group('MAC auto-uppercase', () {
    testWidgets('Stalker MAC field has TextCapitalization.characters', (
      tester,
    ) async {
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
                        () => showAddStalkerDialog(
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

      // The MAC address TextField is the last text field in the Stalker dialog.
      // StalkerFormFields has 3 fields: Name, Portal URL, MAC Address.
      final textFields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      // Last field is MAC Address.
      final macField = textFields.last;
      expect(macField.textCapitalization, TextCapitalization.characters);
    });

    testWidgets(
      'lowercase MAC "aa:bb:cc:dd:ee:ff" is uppercased to "AA:BB:CC:DD:EE:FF" before validation',
      (tester) async {
        // The _StalkerAddDialogState._submit() calls .toUpperCase() before
        // validating: `final mac = _macCtrl.text.trim().toUpperCase()`.
        // So lowercase input is auto-uppercased before the regex check.
        //
        // A valid lowercase MAC should NOT show the format error because
        // after uppercasing it becomes valid.
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
                          () => showAddStalkerDialog(
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
          find.widgetWithText(TextField, 'Portal URL'),
          'http://portal.example.com',
        );
        // Enter lowercase MAC — the dialog uppercases before validation.
        await tester.enterText(
          find.widgetWithText(TextField, 'MAC Address'),
          'aa:bb:cc:dd:ee:ff',
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        // Lowercase MAC is valid after uppercase conversion — no format error.
        expect(
          find.text('Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.'),
          findsNothing,
        );
      },
    );
  });

  // ── StalkerFormFields widget ─────────────────────────────────

  group('StalkerFormFields widget', () {
    testWidgets('renders Name, Portal URL, and MAC Address fields', (
      tester,
    ) async {
      final nameCtrl = TextEditingController();
      final urlCtrl = TextEditingController();
      final macCtrl = TextEditingController();
      addTearDown(nameCtrl.dispose);
      addTearDown(urlCtrl.dispose);
      addTearDown(macCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StalkerFormFields(
              nameCtrl: nameCtrl,
              urlCtrl: urlCtrl,
              macCtrl: macCtrl,
            ),
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Portal URL'), findsOneWidget);
      expect(find.text('MAC Address'), findsOneWidget);
    });

    testWidgets('MAC field has format helper text', (tester) async {
      final nameCtrl = TextEditingController();
      final urlCtrl = TextEditingController();
      final macCtrl = TextEditingController();
      addTearDown(nameCtrl.dispose);
      addTearDown(urlCtrl.dispose);
      addTearDown(macCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StalkerFormFields(
              nameCtrl: nameCtrl,
              urlCtrl: urlCtrl,
              macCtrl: macCtrl,
            ),
          ),
        ),
      );

      expect(find.text('Format: XX:XX:XX:XX:XX:XX'), findsOneWidget);
    });

    testWidgets('MAC field has TextCapitalization.characters set', (
      tester,
    ) async {
      final nameCtrl = TextEditingController();
      final urlCtrl = TextEditingController();
      final macCtrl = TextEditingController();
      addTearDown(nameCtrl.dispose);
      addTearDown(urlCtrl.dispose);
      addTearDown(macCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StalkerFormFields(
              nameCtrl: nameCtrl,
              urlCtrl: urlCtrl,
              macCtrl: macCtrl,
            ),
          ),
        ),
      );

      final textFields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      // Last field in StalkerFormFields is the MAC Address field.
      final macField = textFields.last;
      expect(macField.textCapitalization, TextCapitalization.characters);
    });
  });
}
