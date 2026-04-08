import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'language_settings.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── Minimal AppConfig for tests ───────────────────────────────

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

class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  String? lastSetLocale;
  bool setLocaleCalled = false;

  /// Controls the locale exposed to the widget under test.
  final String? initialLocale;

  _FakeSettingsNotifier({this.initialLocale});

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig(), locale: initialLocale);

  @override
  Future<void> setLocale(String? languageCode) async {
    setLocaleCalled = true;
    lastSetLocale = languageCode;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(locale: languageCode));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Tests ─────────────────────────────────────────────────────

void main() {
  // ── Helper defined inside main() to avoid library_private_types_in_public_api
  Future<_FakeSettingsNotifier> pump(
    WidgetTester tester, {
    String? initialLocale,
  }) async {
    final fake = _FakeSettingsNotifier(initialLocale: initialLocale);
    // Use a tall surface so the bottom sheet can show all 10 locale tiles
    // without any being clipped off-screen.
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsNotifierProvider.overrideWith(() => fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: LanguageSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  group('LanguageSettingsSection', () {
    testWidgets('shows "System Default" subtitle when no locale is set', (
      tester,
    ) async {
      await pump(tester);

      // The ListTile subtitle should show "System Default".
      // There is exactly one tile with that subtitle on the main screen.
      expect(find.text('System Default'), findsOneWidget);
    });

    testWidgets(
      'shows native locale name in subtitle when a locale is selected',
      (tester) async {
        await pump(tester, initialLocale: 'fr');

        // Français appears at least once (as the subtitle of the tile).
        expect(find.text('Français'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('tapping the language tile opens the bottom sheet', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('bottom sheet contains a close button', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('bottom sheet displays all 10 locale options '
        '(System Default + 9 languages)', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      // Verify System Default appears (it will appear in the sheet tile
      // and also as the main-tile subtitle while the sheet is open —
      // so use findsAtLeastNWidgets(1)).
      expect(
        find.text('System Default'),
        findsAtLeastNWidgets(1),
        reason: 'Expected "System Default" in the sheet',
      );

      // The 9 language native names appear exactly once each (only in
      // the sheet, not duplicated anywhere on the main screen).
      const languageNames = [
        'English',
        'العربية',
        'Deutsch',
        'Español',
        'Français',
        'Português',
        'Русский',
        'Türkçe',
        '中文',
      ];
      for (final name in languageNames) {
        expect(
          find.text(name),
          findsOneWidget,
          reason: 'Expected to find locale "$name" in the sheet',
        );
      }
    });

    testWidgets('selected locale tile shows a check_circle icon', (
      tester,
    ) async {
      // When 'de' is selected, the Deutsch tile should have check_circle.
      await pump(tester, initialLocale: 'de');

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      // Exactly one check_circle for the selected locale.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets(
      '"System Default" tile shows a check_circle icon when no locale is set',
      (tester) async {
        await pump(tester);

        await tester.tap(find.byIcon(Icons.translate));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a language calls setLocale with the correct language code',
      (tester) async {
        final fake = await pump(tester);

        await tester.tap(find.byIcon(Icons.translate));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Deutsch'));
        await tester.pumpAndSettle();

        expect(fake.setLocaleCalled, isTrue);
        expect(fake.lastSetLocale, 'de');
      },
    );

    testWidgets('tapping "System Default" calls setLocale with null', (
      tester,
    ) async {
      final fake = await pump(tester, initialLocale: 'ru');

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      // "System Default" appears in both the main tile subtitle and the
      // sheet tile title — use first to hit the sheet tile.
      final systemDefaultFinder = find.text('System Default');
      expect(systemDefaultFinder, findsAtLeastNWidgets(1));
      await tester.tap(systemDefaultFinder.first);
      await tester.pumpAndSettle();

      expect(fake.setLocaleCalled, isTrue);
      expect(fake.lastSetLocale, isNull);
    });

    testWidgets('sheet dismisses after selecting a locale', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsNothing);
    });

    testWidgets(
      'pressing the close button dismisses the sheet without selecting',
      (tester) async {
        final fake = await pump(tester);

        await tester.tap(find.byIcon(Icons.translate));
        await tester.pumpAndSettle();

        expect(find.byType(DraggableScrollableSheet), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(fake.setLocaleCalled, isFalse);
      },
    );
  });

  group('kSupportedLocaleNames constant', () {
    test('contains exactly 9 language entries', () {
      expect(kSupportedLocaleNames.length, 9);
    });

    test('contains all expected language codes', () {
      const expectedCodes = [
        'en',
        'ar',
        'de',
        'es',
        'fr',
        'pt',
        'ru',
        'tr',
        'zh',
      ];
      for (final code in expectedCodes) {
        expect(
          kSupportedLocaleNames.containsKey(code),
          isTrue,
          reason: 'Expected language code "$code" in kSupportedLocaleNames',
        );
      }
    });

    test('native names are non-empty strings', () {
      for (final entry in kSupportedLocaleNames.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'Native name for "${entry.key}" must not be empty',
        );
      }
    });
  });
}
