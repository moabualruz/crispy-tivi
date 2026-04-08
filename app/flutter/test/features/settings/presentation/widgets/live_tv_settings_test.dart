import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'live_tv_settings.dart';

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
  String? lastDefaultScreen;
  bool? lastAutoResumeChannel;
  String? lastResetSection;

  SettingsState _state = SettingsState(
    config: AppConfig(
      appName: 'Test',
      appVersion: '0.0.1',
      api: const ApiConfig(
        baseUrl: 'http://test',
        backendPort: 8080,
        connectTimeoutMs: 5000,
        receiveTimeoutMs: 5000,
        sendTimeoutMs: 5000,
      ),
      player: const PlayerConfig(
        defaultBufferDurationMs: 2000,
        autoPlay: true,
        defaultAspectRatio: '16:9',
      ),
      theme: const ThemeConfig(
        mode: 'dark',
        seedColorHex: '#3B82F6',
        useDynamicColor: false,
      ),
      features: const FeaturesConfig(
        iptvEnabled: true,
        jellyfinEnabled: false,
        plexEnabled: false,
        embyEnabled: false,
      ),
      cache: const CacheConfig(
        epgRefreshIntervalMinutes: 60,
        channelListRefreshIntervalMinutes: 30,
        maxCachedEpgDays: 7,
      ),
    ),
  );

  @override
  Future<SettingsState> build() async => _state;

  @override
  Future<void> setDefaultScreen(String screen) async {
    lastDefaultScreen = screen;
    _state = _state.copyWith(defaultScreen: screen);
    state = AsyncData(_state);
  }

  @override
  Future<void> setAutoResumeChannel(bool enabled) async {
    lastAutoResumeChannel = enabled;
    _state = _state.copyWith(autoResumeChannel: enabled);
    state = AsyncData(_state);
  }

  @override
  Future<void> resetSection(String section) async {
    lastResetSection = section;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Test helpers ──────────────────────────────────────────────

/// Pumps [LiveTvSettingsSection] inside a [ProviderScope] /
/// [MaterialApp] / [Scaffold] scaffold.
Future<void> _pumpLiveTvSettings(
  WidgetTester tester,
  _FakeSettingsNotifier fakeNotifier, {
  String defaultScreen = 'home',
  bool autoResumeChannel = false,
}) async {
  final initialState = SettingsState(
    config: _minimalConfig(),
    defaultScreen: defaultScreen,
    autoResumeChannel: autoResumeChannel,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsNotifierProvider.overrideWith(() => fakeNotifier)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LiveTvSettingsSection(settings: initialState),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────

void main() {
  late _FakeSettingsNotifier fakeNotifier;

  setUp(() {
    fakeNotifier = _FakeSettingsNotifier();
  });

  // ── Default Screen dialog ─────────────────────────────────

  group('Default Screen dialog', () {
    testWidgets('renders Default Screen tile showing "Home" when default', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'home');

      expect(find.text('Default screen after login'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('renders Default Screen tile showing "Live TV" when set', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'live_tv');

      expect(find.text('Default screen after login'), findsOneWidget);
      // "Live TV" appears both as section header and tile subtitle.
      expect(find.text('Live TV'), findsAtLeast(1));
    });

    testWidgets(
      'tapping Default Screen tile opens SimpleDialog with both options',
      (tester) async {
        await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'home');

        await tester.tap(find.text('Default screen after login'));
        await tester.pumpAndSettle();

        expect(find.byType(SimpleDialog), findsOneWidget);
        // Dialog title appears a second time (tile + dialog heading).
        expect(find.text('Default screen after login'), findsNWidgets(2));
        // Both options are present inside the dialog.
        final dialog = find.byType(SimpleDialog);
        expect(
          find.descendant(of: dialog, matching: find.text('Home')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.text('Live TV')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'current selection "home" shows checked radio, other is unchecked',
      (tester) async {
        await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'home');

        await tester.tap(find.text('Default screen after login'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      },
    );

    testWidgets('current selection "live_tv" shows checked radio for Live TV', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'live_tv');

      await tester.tap(find.text('Default screen after login'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('tapping "Live TV" option calls setDefaultScreen("live_tv")', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'home');

      await tester.tap(find.text('Default screen after login'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Live TV'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastDefaultScreen, 'live_tv');
    });

    testWidgets('tapping "Home" option calls setDefaultScreen("home")', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'live_tv');

      await tester.tap(find.text('Default screen after login'));
      await tester.pumpAndSettle();

      // In the dialog, find the "Home" option (not the subtitle).
      // The dialog title is 'Default screen after login'.
      // The options are 'Home' and 'Live TV'.
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastDefaultScreen, 'home');
    });

    testWidgets('dialog dismisses after selection', (tester) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, defaultScreen: 'home');

      await tester.tap(find.text('Default screen after login'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Live TV'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing);
    });
  });

  // ── Auto-resume toggle ────────────────────────────────────

  group('Auto-resume toggle', () {
    testWidgets('renders toggle with correct label', (tester) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, autoResumeChannel: false);

      expect(find.text('Auto-resume last channel'), findsOneWidget);
    });

    testWidgets('toggle is off when autoResumeChannel is false', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, autoResumeChannel: false);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);
    });

    testWidgets('toggle is on when autoResumeChannel is true', (tester) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, autoResumeChannel: true);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('tapping toggle when off calls setAutoResumeChannel(true)', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, autoResumeChannel: false);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastAutoResumeChannel, isTrue);
    });

    testWidgets('tapping toggle when on calls setAutoResumeChannel(false)', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier, autoResumeChannel: true);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastAutoResumeChannel, isFalse);
    });
  });

  // ── Reset Live TV Settings ────────────────────────────────

  group('Reset Live TV Settings', () {
    testWidgets('Reset button is present in section header', (tester) async {
      await _pumpLiveTvSettings(tester, fakeNotifier);

      expect(find.byTooltip('Reset to defaults'), findsOneWidget);
    });

    testWidgets('tapping Reset shows confirmation AlertDialog', (tester) async {
      await _pumpLiveTvSettings(tester, fakeNotifier);

      await tester.tap(find.byTooltip('Reset to defaults'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Reset Live TV Settings'), findsOneWidget);
      expect(
        find.text('Reset all settings to their factory defaults?'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel button closes dialog without resetting', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier);

      await tester.tap(find.byTooltip('Reset to defaults'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fakeNotifier.lastResetSection, isNull);
    });

    testWidgets('confirming reset calls resetSection("liveTV")', (
      tester,
    ) async {
      await _pumpLiveTvSettings(tester, fakeNotifier);

      await tester.tap(find.byTooltip('Reset to defaults'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastResetSection, 'liveTV');
    });

    testWidgets('dialog closes after confirming reset', (tester) async {
      await _pumpLiveTvSettings(tester, fakeNotifier);

      await tester.tap(find.byTooltip('Reset to defaults'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
