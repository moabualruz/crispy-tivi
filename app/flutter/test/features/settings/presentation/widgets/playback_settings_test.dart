import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/features/player/domain/segment_skip_config.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/'
    'screensaver_overlay.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'playback_settings.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'screensaver_settings.dart';

// ── Minimal AppConfig builders ────────────────────────────────

AppConfig _configWith({
  bool afrEnabled = false,
  bool afrLiveTv = true,
  bool afrVod = true,
  bool showSkipButtons = true,
  String nextUpMode = 'static',
}) => AppConfig(
  appName: 'Test',
  appVersion: '0.0.1',
  api: const ApiConfig(
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
    afrEnabled: afrEnabled,
    afrLiveTv: afrLiveTv,
    afrVod: afrVod,
    showSkipButtons: showSkipButtons,
    nextUpMode: nextUpMode,
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
);

// ── Fake SettingsNotifier ─────────────────────────────────────

class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  _FakeSettingsNotifier(this._initial);

  final SettingsState _initial;

  late SettingsState _state;

  // ── Captured call args ──────────────────────────
  bool? lastAfrEnabled;
  bool? lastAfrLiveTv;
  bool? lastAfrVod;
  bool? lastShowSkipButtons;
  String? lastSegmentSkipConfig;
  String? lastNextUpMode;
  ScreensaverMode? lastScreensaverMode;
  int? lastScreensaverTimeout;

  @override
  Future<SettingsState> build() async {
    _state = _initial;
    return _state;
  }

  @override
  Future<void> setAfrEnabled(bool enabled) async {
    lastAfrEnabled = enabled;
    _state = SettingsState(
      config: _configWith(
        afrEnabled: enabled,
        afrLiveTv: _state.config.player.afrLiveTv,
        afrVod: _state.config.player.afrVod,
        showSkipButtons: _state.config.player.showSkipButtons,
        nextUpMode: _state.config.player.nextUpMode,
      ),
    );
    state = AsyncData(_state);
  }

  @override
  Future<void> setAfrLiveTv(bool enabled) async {
    lastAfrLiveTv = enabled;
  }

  @override
  Future<void> setAfrVod(bool enabled) async {
    lastAfrVod = enabled;
  }

  @override
  Future<void> setShowSkipButtons(bool enabled) async {
    lastShowSkipButtons = enabled;
    _state = SettingsState(
      config: _configWith(
        afrEnabled: _state.config.player.afrEnabled,
        showSkipButtons: enabled,
        nextUpMode: _state.config.player.nextUpMode,
      ),
    );
    state = AsyncData(_state);
  }

  @override
  Future<void> setSegmentSkipConfig(String config) async {
    lastSegmentSkipConfig = config;
  }

  @override
  Future<void> setNextUpMode(String mode) async {
    lastNextUpMode = mode;
  }

  @override
  Future<void> setScreensaverMode(ScreensaverMode mode) async {
    lastScreensaverMode = mode;
  }

  @override
  Future<void> setScreensaverTimeout(int minutes) async {
    lastScreensaverTimeout = minutes;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Pump helpers ──────────────────────────────────────────────

/// Pumps [PlaybackSettingsSection] with the given config state.
Future<_FakeSettingsNotifier> _pumpPlayback(
  WidgetTester tester, {
  bool afrEnabled = false,
  bool afrLiveTv = true,
  bool afrVod = true,
  bool showSkipButtons = true,
  String nextUpMode = 'static',
}) async {
  final config = _configWith(
    afrEnabled: afrEnabled,
    afrLiveTv: afrLiveTv,
    afrVod: afrVod,
    showSkipButtons: showSkipButtons,
    nextUpMode: nextUpMode,
  );
  final fakeNotifier = _FakeSettingsNotifier(SettingsState(config: config));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsNotifierProvider.overrideWith(() => fakeNotifier)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PlaybackSettingsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeNotifier;
}

/// Pumps [ScreensaverSettingsSection] with the given state values.
Future<_FakeSettingsNotifier> _pumpScreensaver(
  WidgetTester tester, {
  ScreensaverMode screensaverMode = ScreensaverMode.bouncingLogo,
  int screensaverTimeout = 0,
}) async {
  final config = _configWith();
  final settings = SettingsState(
    config: config,
    screensaverMode: screensaverMode,
    screensaverTimeout: screensaverTimeout,
  );
  final fakeNotifier = _FakeSettingsNotifier(settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsNotifierProvider.overrideWith(() => fakeNotifier)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScreensaverSettingsSection(settings: settings),
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
  // ── AFR (Auto Frame Rate) ─────────────────────────────────

  group('AFR (Auto Frame Rate)', () {
    testWidgets('renders AFR toggle with correct label', (tester) async {
      await _pumpPlayback(tester, afrEnabled: false);

      expect(find.text('Auto Frame Rate'), findsOneWidget);
      expect(find.text('Match display refresh to video FPS'), findsOneWidget);
    });

    testWidgets('AFR sub-toggles NOT visible when AFR is off', (tester) async {
      await _pumpPlayback(tester, afrEnabled: false);

      expect(find.text('Apply to Live TV'), findsNothing);
      expect(find.text('Apply to VOD'), findsNothing);
    });

    testWidgets('AFR sub-toggles appear when AFR is on', (tester) async {
      await _pumpPlayback(tester, afrEnabled: true);

      expect(find.text('Apply to Live TV'), findsOneWidget);
      expect(find.text('Apply to VOD'), findsOneWidget);
    });

    testWidgets('AFR switch is off when afrEnabled is false', (tester) async {
      await _pumpPlayback(tester, afrEnabled: false);

      // First Switch in the widget tree is the AFR toggle.
      final afrSwitch = tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(afrSwitch.value, isFalse);
    });

    testWidgets('AFR switch is on when afrEnabled is true', (tester) async {
      await _pumpPlayback(tester, afrEnabled: true);

      final afrSwitch = tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(afrSwitch.value, isTrue);
    });

    testWidgets('toggling AFR switch off→on calls setAfrEnabled(true)', (
      tester,
    ) async {
      final fake = await _pumpPlayback(tester, afrEnabled: false);

      // Tap the AFR SwitchListTile.
      await tester.tap(find.text('Auto Frame Rate'));
      await tester.pumpAndSettle();

      expect(fake.lastAfrEnabled, isTrue);
    });

    testWidgets('toggling AFR switch on→off calls setAfrEnabled(false)', (
      tester,
    ) async {
      final fake = await _pumpPlayback(tester, afrEnabled: true);

      await tester.tap(find.text('Auto Frame Rate'));
      await tester.pumpAndSettle();

      expect(fake.lastAfrEnabled, isFalse);
    });

    testWidgets('Apply to Live TV sub-toggle is on when afrLiveTv is true', (
      tester,
    ) async {
      await _pumpPlayback(tester, afrEnabled: true, afrLiveTv: true);

      // The second Switch in the tree is the Live TV sub-toggle.
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[1].value, isTrue);
    });

    testWidgets('Apply to Live TV sub-toggle is off when afrLiveTv is false', (
      tester,
    ) async {
      await _pumpPlayback(tester, afrEnabled: true, afrLiveTv: false);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[1].value, isFalse);
    });

    testWidgets('tapping Apply to Live TV sub-toggle calls setAfrLiveTv', (
      tester,
    ) async {
      final fake = await _pumpPlayback(
        tester,
        afrEnabled: true,
        afrLiveTv: true,
      );

      await tester.tap(find.text('Apply to Live TV'));
      await tester.pumpAndSettle();

      expect(fake.lastAfrLiveTv, isFalse);
    });

    testWidgets('Apply to VOD sub-toggle is on when afrVod is true', (
      tester,
    ) async {
      await _pumpPlayback(tester, afrEnabled: true, afrVod: true);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // Third Switch is the VOD sub-toggle.
      expect(switches[2].value, isTrue);
    });

    testWidgets('tapping Apply to VOD sub-toggle calls setAfrVod', (
      tester,
    ) async {
      final fake = await _pumpPlayback(tester, afrEnabled: true, afrVod: true);

      await tester.tap(find.text('Apply to VOD'));
      await tester.pumpAndSettle();

      expect(fake.lastAfrVod, isFalse);
    });
  });

  // ── Skip Intro / Credits Buttons ──────────────────────────

  group('SkipIntro / Credits Buttons', () {
    testWidgets('renders Skip Intro tile with correct label', (tester) async {
      await _pumpPlayback(tester, showSkipButtons: false);

      expect(find.text('Skip Intro / Credits Buttons'), findsOneWidget);
    });

    testWidgets(
      'Segment Skip Behavior tile NOT visible when showSkipButtons is false',
      (tester) async {
        await _pumpPlayback(tester, showSkipButtons: false);

        expect(find.text('Segment Skip Behavior'), findsNothing);
      },
    );

    testWidgets(
      'Segment Skip Behavior tile visible when showSkipButtons is true',
      (tester) async {
        await _pumpPlayback(tester, showSkipButtons: true);

        expect(find.text('Segment Skip Behavior'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Skip Intro toggle false→true calls setShowSkipButtons(true)',
      (tester) async {
        final fake = await _pumpPlayback(tester, showSkipButtons: false);

        await tester.tap(find.text('Skip Intro / Credits Buttons'));
        await tester.pumpAndSettle();

        expect(fake.lastShowSkipButtons, isTrue);
      },
    );

    testWidgets(
      'tapping Skip Intro toggle true→false calls setShowSkipButtons(false)',
      (tester) async {
        final fake = await _pumpPlayback(tester, showSkipButtons: true);

        await tester.tap(find.text('Skip Intro / Credits Buttons'));
        await tester.pumpAndSettle();

        expect(fake.lastShowSkipButtons, isFalse);
      },
    );

    testWidgets('tapping Segment Skip Behavior tile opens AlertDialog', (
      tester,
    ) async {
      await _pumpPlayback(tester, showSkipButtons: true);

      await tester.tap(find.text('Segment Skip Behavior'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Segment Skip Behavior'), findsNWidgets(2));
    });

    testWidgets('Segment Skip dialog shows all 5 segment types', (
      tester,
    ) async {
      await _pumpPlayback(tester, showSkipButtons: true);

      await tester.tap(find.text('Segment Skip Behavior'));
      await tester.pumpAndSettle();

      for (final type in SegmentType.values) {
        expect(find.text(type.label), findsOneWidget);
      }
    });

    testWidgets('Segment Skip dialog has Cancel and Save buttons', (
      tester,
    ) async {
      await _pumpPlayback(tester, showSkipButtons: true);

      await tester.tap(find.text('Segment Skip Behavior'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Cancel closes Segment Skip dialog without saving', (
      tester,
    ) async {
      final fake = await _pumpPlayback(tester, showSkipButtons: true);

      await tester.tap(find.text('Segment Skip Behavior'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.lastSegmentSkipConfig, isNull);
    });

    testWidgets('Save calls setSegmentSkipConfig and closes dialog', (
      tester,
    ) async {
      final fake = await _pumpPlayback(tester, showSkipButtons: true);

      await tester.tap(find.text('Segment Skip Behavior'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.lastSegmentSkipConfig, isNotNull);
    });
  });

  // ── Next-Up Overlay dialog ────────────────────────────────

  group('Next-Up Overlay dialog', () {
    testWidgets('renders Next-Up Overlay tile', (tester) async {
      await _pumpPlayback(tester, nextUpMode: 'static');

      expect(find.text('Next-Up Overlay'), findsOneWidget);
    });

    testWidgets('tile subtitle shows current mode label', (tester) async {
      await _pumpPlayback(tester, nextUpMode: 'off');

      expect(find.text(NextUpMode.off.label), findsOneWidget);
    });

    testWidgets(
      'tile subtitle shows "Static (32s before end)" when nextUpMode is static',
      (tester) async {
        await _pumpPlayback(tester, nextUpMode: 'static');

        expect(find.text(NextUpMode.static.label), findsOneWidget);
      },
    );

    testWidgets('tapping Next-Up Overlay tile opens SimpleDialog', (
      tester,
    ) async {
      await _pumpPlayback(tester, nextUpMode: 'static');

      await tester.ensureVisible(find.text('Next-Up Overlay'));
      await tester.tap(find.text('Next-Up Overlay'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);
    });

    testWidgets('dialog shows all 3 NextUpMode options', (tester) async {
      await _pumpPlayback(tester, nextUpMode: 'static');

      await tester.ensureVisible(find.text('Next-Up Overlay'));
      await tester.tap(find.text('Next-Up Overlay'));
      await tester.pumpAndSettle();

      for (final mode in NextUpMode.values) {
        expect(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text(mode.label),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('current mode "static" shows checked radio, others unchecked', (
      tester,
    ) async {
      await _pumpPlayback(tester, nextUpMode: 'static');

      await tester.ensureVisible(find.text('Next-Up Overlay'));
      await tester.tap(find.text('Next-Up Overlay'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(NextUpMode.values.length - 1),
      );
    });

    testWidgets('current mode "off" shows checked radio on Off option', (
      tester,
    ) async {
      await _pumpPlayback(tester, nextUpMode: 'off');

      await tester.ensureVisible(find.text('Next-Up Overlay'));
      await tester.tap(find.text('Next-Up Overlay'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('tapping "Off" option calls setNextUpMode("off")', (
      tester,
    ) async {
      final fake = await _pumpPlayback(tester, nextUpMode: 'static');

      await tester.ensureVisible(find.text('Next-Up Overlay'));
      await tester.tap(find.text('Next-Up Overlay'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(NextUpMode.off.label),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.lastNextUpMode, NextUpMode.off.name);
    });

    testWidgets(
      'tapping "Smart (credits-aware)" calls setNextUpMode("smart")',
      (tester) async {
        final fake = await _pumpPlayback(tester, nextUpMode: 'static');

        await tester.ensureVisible(find.text('Next-Up Overlay'));
        await tester.tap(find.text('Next-Up Overlay'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text(NextUpMode.smart.label),
          ),
        );
        await tester.pumpAndSettle();

        expect(fake.lastNextUpMode, NextUpMode.smart.name);
      },
    );

    testWidgets('dialog closes after selecting an option', (tester) async {
      await _pumpPlayback(tester, nextUpMode: 'static');

      await tester.ensureVisible(find.text('Next-Up Overlay'));
      await tester.tap(find.text('Next-Up Overlay'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(NextUpMode.off.label),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing);
    });
  });

  // ── Idle Timeout dialog (ScreensaverSettingsSection) ──────

  group('Idle Timeout dialog', () {
    testWidgets('renders Idle Timeout tile with label', (tester) async {
      await _pumpScreensaver(tester, screensaverTimeout: 0);

      expect(find.text('Idle Timeout'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('shows correct label for 5 minutes', (tester) async {
      await _pumpScreensaver(tester, screensaverTimeout: 5);

      expect(find.text('5 minutes'), findsOneWidget);
    });

    testWidgets('tapping Idle Timeout tile opens SimpleDialog', (tester) async {
      await _pumpScreensaver(tester, screensaverTimeout: 0);

      await tester.tap(find.text('Idle Timeout'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);
      expect(find.text('Screensaver Idle Timeout'), findsOneWidget);
    });

    testWidgets('dialog shows all 5 timeout options', (tester) async {
      await _pumpScreensaver(tester, screensaverTimeout: 0);

      await tester.tap(find.text('Idle Timeout'));
      await tester.pumpAndSettle();

      // kScreensaverTimeoutOptions = [0, 2, 5, 10, 30]
      expect(find.text('Disabled'), findsNWidgets(2)); // tile + option
      expect(find.text('2 minutes'), findsOneWidget);
      expect(find.text('5 minutes'), findsOneWidget);
      expect(find.text('10 minutes'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
    });

    testWidgets('current selection "Disabled" shows checked radio', (
      tester,
    ) async {
      await _pumpScreensaver(tester, screensaverTimeout: 0);

      await tester.tap(find.text('Idle Timeout'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      // 4 other options are unchecked.
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
    });

    testWidgets('tapping "5 minutes" calls setScreensaverTimeout(5)', (
      tester,
    ) async {
      final fake = await _pumpScreensaver(tester, screensaverTimeout: 0);

      await tester.tap(find.text('Idle Timeout'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('5 minutes'));
      await tester.pumpAndSettle();

      expect(fake.lastScreensaverTimeout, 5);
    });

    testWidgets('tapping "Disabled" calls setScreensaverTimeout(0)', (
      tester,
    ) async {
      final fake = await _pumpScreensaver(tester, screensaverTimeout: 10);

      await tester.tap(find.text('Idle Timeout'));
      await tester.pumpAndSettle();

      // "Disabled" appears in dialog options.
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Disabled'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.lastScreensaverTimeout, 0);
    });

    testWidgets('dialog closes after selecting timeout', (tester) async {
      await _pumpScreensaver(tester, screensaverTimeout: 0);

      await tester.tap(find.text('Idle Timeout'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);

      await tester.tap(find.text('2 minutes'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing);
    });
  });

  // ── Screensaver Mode dialog ───────────────────────────────

  group('Screensaver Mode dialog', () {
    testWidgets('renders Screensaver Mode tile', (tester) async {
      await _pumpScreensaver(
        tester,
        screensaverMode: ScreensaverMode.bouncingLogo,
      );

      expect(find.text('Screensaver Mode'), findsOneWidget);
      expect(find.text(ScreensaverMode.bouncingLogo.label), findsOneWidget);
    });

    testWidgets('tile subtitle shows current screensaver mode label', (
      tester,
    ) async {
      await _pumpScreensaver(tester, screensaverMode: ScreensaverMode.clock);

      expect(find.text(ScreensaverMode.clock.label), findsOneWidget);
    });

    testWidgets('tapping Screensaver Mode tile opens SimpleDialog', (
      tester,
    ) async {
      await _pumpScreensaver(
        tester,
        screensaverMode: ScreensaverMode.bouncingLogo,
      );

      await tester.tap(find.text('Screensaver Mode'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);
      expect(find.text('Screensaver Mode'), findsNWidgets(2));
    });

    testWidgets('dialog shows all 3 screensaver modes', (tester) async {
      await _pumpScreensaver(
        tester,
        screensaverMode: ScreensaverMode.bouncingLogo,
      );

      await tester.tap(find.text('Screensaver Mode'));
      await tester.pumpAndSettle();

      for (final mode in ScreensaverMode.values) {
        expect(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text(mode.label),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('current mode shows checked radio, others unchecked', (
      tester,
    ) async {
      await _pumpScreensaver(tester, screensaverMode: ScreensaverMode.clock);

      await tester.tap(find.text('Screensaver Mode'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(ScreensaverMode.values.length - 1),
      );
    });

    testWidgets(
      'tapping "Black Screen" calls setScreensaverMode(blackScreen)',
      (tester) async {
        final fake = await _pumpScreensaver(
          tester,
          screensaverMode: ScreensaverMode.bouncingLogo,
        );

        await tester.tap(find.text('Screensaver Mode'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text(ScreensaverMode.blackScreen.label),
          ),
        );
        await tester.pumpAndSettle();

        expect(fake.lastScreensaverMode, ScreensaverMode.blackScreen);
      },
    );

    testWidgets('tapping "Clock" calls setScreensaverMode(clock)', (
      tester,
    ) async {
      final fake = await _pumpScreensaver(
        tester,
        screensaverMode: ScreensaverMode.bouncingLogo,
      );

      await tester.tap(find.text('Screensaver Mode'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(ScreensaverMode.clock.label),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.lastScreensaverMode, ScreensaverMode.clock);
    });

    testWidgets('dialog closes after selecting a mode', (tester) async {
      await _pumpScreensaver(
        tester,
        screensaverMode: ScreensaverMode.bouncingLogo,
      );

      await tester.tap(find.text('Screensaver Mode'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(ScreensaverMode.clock.label),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing);
    });
  });
}
