import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/theme/accent_color.dart';
import 'package:crispy_tivi/core/theme/main_color_hue.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/core/widgets/density_mode.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'settings_shared_widgets.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'theme_dialogs.dart';

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

// ── Fake ThemeNotifier ────────────────────────────────────────
class _FakeThemeNotifier extends Notifier<ThemeState> implements ThemeNotifier {
  MainColorHue? lastMainHue;
  AccentColor? lastAccent;
  UiDensity? lastDensity;
  bool wasReset = false;
  ThemeState _state;

  _FakeThemeNotifier({ThemeState? initialState})
    : _state = initialState ?? const ThemeState();

  @override
  ThemeState build() => _state;

  @override
  Future<void> setMainHue(MainColorHue hue) async {
    lastMainHue = hue;
    _state = _state.copyWith(mainHue: hue);
    state = _state;
  }

  @override
  Future<void> setAccent(AccentColor accent) async {
    lastAccent = accent;
    _state = _state.copyWith(accent: accent);
    state = _state;
  }

  @override
  Future<void> setDensity(UiDensity density) async {
    lastDensity = density;
    _state = _state.copyWith(density: density);
    state = _state;
  }

  @override
  Future<void> reset() async {
    wasReset = true;
    _state = const ThemeState();
    state = _state;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Fake SettingsNotifier ─────────────────────────────────────
class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  DensityMode? lastGridDensity;
  bool sectionResetCalled = false;
  String? lastResetSection;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());

  @override
  Future<void> setGridDensity(DensityMode mode) async {
    lastGridDensity = mode;
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(gridDensity: mode));
    }
  }

  @override
  Future<void> resetSection(String section) async {
    sectionResetCalled = true;
    lastResetSection = section;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakeThemeNotifier fakeTheme;
  late _FakeSettingsNotifier fakeSettings;

  setUp(() {
    fakeTheme = _FakeThemeNotifier();
    fakeSettings = _FakeSettingsNotifier();
  });

  // ── Helper: pump a scaffold that opens a dialog via a button ──
  //
  // Defined inside main() to avoid library_private_types_in_public_api
  // lint on the private fake notifier parameters.
  Future<void> pumpDialogTrigger(
    WidgetTester tester, {
    required void Function(BuildContext, WidgetRef) onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith(() => fakeTheme),
          settingsNotifierProvider.overrideWith(() => fakeSettings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () => onTap(context, ref),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ── showMainHueDialog ─────────────────────────────────────

  group('ThemeBase dialog', () {
    testWidgets('renders one option per MainColorHue value', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showMainHueDialog(ctx, ref, MainColorHue.warmBlack);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final hue in MainColorHue.values) {
        expect(find.text(hue.displayName), findsOneWidget);
      }
      expect(
        find.byType(MainHueOption),
        findsNWidgets(MainColorHue.values.length),
      );
    });

    testWidgets('shows check_circle icon for current hue', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showMainHueDialog(ctx, ref, MainColorHue.coolBlack);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Only one hue is selected — check_circle appears once.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping a hue option calls setMainHue', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showMainHueDialog(ctx, ref, MainColorHue.warmBlack);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(MainColorHue.purpleBlack.displayName));
      await tester.pumpAndSettle();

      expect(fakeTheme.lastMainHue, MainColorHue.purpleBlack);
    });

    testWidgets('dialog dismisses after hue selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showMainHueDialog(ctx, ref, MainColorHue.warmBlack);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Theme Base'), findsOneWidget);

      await tester.tap(find.text(MainColorHue.pureBlack.displayName));
      await tester.pumpAndSettle();

      expect(find.text('Theme Base'), findsNothing);
    });

    testWidgets('Cancel button closes the dialog without selecting', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showMainHueDialog(ctx, ref, MainColorHue.warmBlack);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Theme Base'), findsNothing);
      expect(fakeTheme.lastMainHue, isNull);
    });
  });

  // ── showAccentColorDialog ─────────────────────────────────

  group('AccentColor dialog', () {
    testWidgets('renders one chip per non-custom AccentColor', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAccentColorDialog(ctx, ref, AccentColor.blue, null);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final nonCustom =
          AccentColor.values.where((a) => a != AccentColor.custom).toList();
      expect(find.byType(AccentColorChip), findsNWidgets(nonCustom.length));
    });

    testWidgets('shows check icon for current accent', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAccentColorDialog(ctx, ref, AccentColor.teal, null);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // AccentColorChip shows Icons.check when selected.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping a chip calls setAccent', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAccentColorDialog(ctx, ref, AccentColor.blue, null);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the GestureDetector inside the second AccentColorChip
      // (index 1 = red, since index 0 = blue is the current selection).
      // The GestureDetector wraps the colored circle; the label Text
      // is outside it, so we must tap via the GestureDetector.
      final chipFinder = find.byType(AccentColorChip);
      await tester.tap(
        find.descendant(
          of: chipFinder.at(1),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeTheme.lastAccent, AccentColor.red);
    });

    testWidgets('dialog dismisses after accent selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAccentColorDialog(ctx, ref, AccentColor.blue, null);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Accent Color'), findsOneWidget);

      // Tap the GestureDetector inside the 5th chip (purple, index 4).
      final chipFinder = find.byType(AccentColorChip);
      await tester.tap(
        find.descendant(
          of: chipFinder.at(4),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accent Color'), findsNothing);
    });

    testWidgets('Cancel button closes dialog without selecting', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAccentColorDialog(ctx, ref, AccentColor.blue, null);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Accent Color'), findsNothing);
      expect(fakeTheme.lastAccent, isNull);
    });
  });

  // ── showDensityDialog ─────────────────────────────────────

  group('UiDensity dialog', () {
    testWidgets('renders one option per UiDensity value', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showDensityDialog(ctx, ref, UiDensity.standard);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final d in UiDensity.values) {
        expect(find.text(d.label), findsOneWidget);
      }
      expect(
        find.byType(DensityOption),
        findsNWidgets(UiDensity.values.length),
      );
    });

    testWidgets('shows check_circle icon for current density', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showDensityDialog(ctx, ref, UiDensity.compact);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Only one density is selected.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping a density option calls setDensity', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showDensityDialog(ctx, ref, UiDensity.standard);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(UiDensity.comfortable.label));
      await tester.pumpAndSettle();

      expect(fakeTheme.lastDensity, UiDensity.comfortable);
    });

    testWidgets('dialog dismisses after density selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showDensityDialog(ctx, ref, UiDensity.standard);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('UI Density'), findsOneWidget);

      await tester.tap(find.text(UiDensity.compact.label));
      await tester.pumpAndSettle();

      expect(find.text('UI Density'), findsNothing);
    });

    testWidgets('Cancel button closes dialog without selecting', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showDensityDialog(ctx, ref, UiDensity.standard);
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('UI Density'), findsNothing);
      expect(fakeTheme.lastDensity, isNull);
    });
  });

  // ── _GridDensityTile (SegmentedButton) ────────────────────

  group('GridDensity segmented button', () {
    /// Pumps a standalone SegmentedButton for DensityMode selection,
    /// mirroring the _GridDensityTile widget in AppearanceSettingsSection.
    Future<void> pumpGridDensity(
      WidgetTester tester,
      DensityMode current,
    ) async {
      final notifier = _FakeSettingsNotifier();
      fakeSettings = notifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWith(() => fakeTheme),
            settingsNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Consumer(
                  builder: (context, ref, _) {
                    return Column(
                      children: [
                        ListTile(
                          title: const Text('Grid density'),
                          subtitle: Text(current.label),
                          trailing: SegmentedButton<DensityMode>(
                            segments: [
                              for (final mode in DensityMode.values)
                                ButtonSegment(
                                  value: mode,
                                  icon: Icon(mode.icon),
                                  tooltip: mode.label,
                                ),
                            ],
                            selected: {current},
                            onSelectionChanged: (s) {
                              ref
                                  .read(settingsNotifierProvider.notifier)
                                  .setGridDensity(s.first);
                            },
                            showSelectedIcon: false,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders SegmentedButton with 3 DensityMode segments', (
      tester,
    ) async {
      await pumpGridDensity(tester, DensityMode.comfortable);

      expect(find.byType(SegmentedButton<DensityMode>), findsOneWidget);
      // All 3 density icons are present.
      for (final mode in DensityMode.values) {
        expect(find.byIcon(mode.icon), findsWidgets);
      }
    });

    testWidgets('current selection is highlighted', (tester) async {
      await pumpGridDensity(tester, DensityMode.spacious);

      final button = tester.widget<SegmentedButton<DensityMode>>(
        find.byType(SegmentedButton<DensityMode>),
      );
      expect(button.selected, {DensityMode.spacious});
    });

    testWidgets('tapping a segment calls setGridDensity', (tester) async {
      await pumpGridDensity(tester, DensityMode.comfortable);

      // Tap the compact segment icon.
      await tester.tap(find.byIcon(DensityMode.compact.icon).first);
      await tester.pumpAndSettle();

      expect(fakeSettings.lastGridDensity, DensityMode.compact);
    });
  });

  // ── Reset Appearance button ───────────────────────────────

  group('Reset Appearance', () {
    /// Pumps a minimal widget that opens the reset confirmation dialog
    /// via [showSettingsResetDialog] when the restore icon is tapped.
    Future<void> pumpResetButton(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWith(() => fakeTheme),
            settingsNotifierProvider.overrideWith(() => fakeSettings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Reset to defaults',
                    onPressed:
                        () => showSettingsResetDialog(
                          context,
                          ref,
                          'Reset Appearance',
                          'appearance',
                        ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping Reset icon shows confirmation dialog', (tester) async {
      await pumpResetButton(tester);

      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      expect(find.text('Reset Appearance'), findsOneWidget);
      expect(
        find.text('Reset all settings to their factory defaults?'),
        findsOneWidget,
      );
    });

    testWidgets('confirming reset calls resetSection("appearance")', (
      tester,
    ) async {
      await pumpResetButton(tester);

      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(fakeSettings.sectionResetCalled, isTrue);
      expect(fakeSettings.lastResetSection, 'appearance');
    });

    testWidgets('cancelling reset does not call resetSection', (tester) async {
      await pumpResetButton(tester);

      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeSettings.sectionResetCalled, isFalse);
      expect(find.text('Reset Appearance'), findsNothing);
    });
  });
}
