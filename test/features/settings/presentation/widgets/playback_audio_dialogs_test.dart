import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/utils/timezone_utils.dart';
import 'package:crispy_tivi/features/player/domain/entities/audio_output.dart';
import 'package:crispy_tivi/features/player/domain/entities/passthrough_codec.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'playback_audio_dialogs.dart';

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
  String? lastEpgTimezone;
  String? lastAudioOutput;
  List<String>? lastPassthroughCodecs;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());

  @override
  Future<void> setEpgTimezone(String timezone) async {
    lastEpgTimezone = timezone;
  }

  @override
  Future<void> setAudioOutput(String output) async {
    lastAudioOutput = output;
  }

  @override
  Future<void> setAudioPassthroughCodecs(List<String> codecs) async {
    lastPassthroughCodecs = codecs;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Helper: pump a scaffold with a button that opens a dialog ─

Future<void> _pumpDialogTrigger(
  WidgetTester tester,
  _FakeSettingsNotifier fakeNotifier, {
  required void Function(BuildContext, WidgetRef) onTap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsNotifierProvider.overrideWith(() => fakeNotifier)],
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

// ── Tests ─────────────────────────────────────────────────────

void main() {
  // ── Timezone dialog ────────────────────────────────────────

  group('Timezone dialog', () {
    late _FakeSettingsNotifier fakeNotifier;

    setUp(() {
      fakeNotifier = _FakeSettingsNotifier();
    });

    testWidgets('lists all available timezone labels', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showTimezoneDialog(
            context: ctx,
            ref: ref,
            currentTimezone: 'system',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Every timezone label defined in TimezoneUtils should appear.
      for (final label in TimezoneUtils.timezoneLabels.values) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows UTC offset description for each timezone', (
      tester,
    ) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showTimezoneDialog(
            context: ctx,
            ref: ref,
            currentTimezone: 'UTC',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // UTC offset labels (e.g., 'UTC+0:00') should appear in the dialog.
      expect(find.textContaining('UTC'), findsWidgets);
    });

    testWidgets('current timezone shows checked radio icon', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showTimezoneDialog(
            context: ctx,
            ref: ref,
            currentTimezone: 'UTC',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Exactly one checked radio for the current timezone.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('non-selected timezones show unchecked radio icons', (
      tester,
    ) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showTimezoneDialog(
            context: ctx,
            ref: ref,
            currentTimezone: 'UTC',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final total = TimezoneUtils.availableTimezones.length;
      // All timezones except the current one show unchecked.
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(total - 1),
      );
    });

    testWidgets('tapping a timezone calls setEpgTimezone', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showTimezoneDialog(
            context: ctx,
            ref: ref,
            currentTimezone: 'system',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the 'UTC (No offset)' option.
      await tester.tap(find.text('UTC (No offset)'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastEpgTimezone, 'UTC');
    });

    testWidgets('dialog dismisses after selecting a timezone', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showTimezoneDialog(
            context: ctx,
            ref: ref,
            currentTimezone: 'system',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('EPG Timezone'), findsOneWidget);

      await tester.tap(find.text('UTC (No offset)'));
      await tester.pumpAndSettle();

      expect(find.text('EPG Timezone'), findsNothing);
    });

    testWidgets('renders dialog title "EPG Timezone"', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showTimezoneDialog(
            context: ctx,
            ref: ref,
            currentTimezone: 'system',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('EPG Timezone'), findsOneWidget);
    });
  });

  // ── AudioOutput dialog ────────────────────────────────────

  group('AudioOutput dialog', () {
    late _FakeSettingsNotifier fakeNotifier;

    setUp(() {
      fakeNotifier = _FakeSettingsNotifier();
    });

    testWidgets('shows platform-filtered options', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showAudioOutputDialog(
            context: ctx,
            ref: ref,
            currentOutput: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // All platform-available audio outputs should appear.
      final available = AudioOutput.availableForCurrentPlatform;
      for (final output in available) {
        expect(find.text(output.label), findsOneWidget);
      }
    });

    testWidgets('shows description for each option', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showAudioOutputDialog(
            context: ctx,
            ref: ref,
            currentOutput: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final available = AudioOutput.availableForCurrentPlatform;
      for (final output in available) {
        expect(find.text(output.description), findsOneWidget);
      }
    });

    testWidgets('current selection shows checked radio icon', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showAudioOutputDialog(
            context: ctx,
            ref: ref,
            currentOutput: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Exactly one checked radio icon for the current selection.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('non-selected options show unchecked radio icons', (
      tester,
    ) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showAudioOutputDialog(
            context: ctx,
            ref: ref,
            currentOutput: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final available = AudioOutput.availableForCurrentPlatform;
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(available.length - 1),
      );
    });

    testWidgets('tapping an option calls setAudioOutput with mpvValue', (
      tester,
    ) async {
      final available = AudioOutput.availableForCurrentPlatform;
      // Need at least 2 options to pick one different from current.
      if (available.length < 2) return;

      final targetOutput = available[1];

      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showAudioOutputDialog(
            context: ctx,
            ref: ref,
            currentOutput: available[0].mpvValue,
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(targetOutput.label));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastAudioOutput, targetOutput.mpvValue);
    });

    testWidgets('dialog dismisses after selection', (tester) async {
      final available = AudioOutput.availableForCurrentPlatform;
      if (available.length < 2) return;

      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showAudioOutputDialog(
            context: ctx,
            ref: ref,
            currentOutput: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Audio Output'), findsOneWidget);

      await tester.tap(find.text(available[1].label));
      await tester.pumpAndSettle();

      expect(find.text('Audio Output'), findsNothing);
    });

    testWidgets('renders dialog title "Audio Output"', (tester) async {
      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showAudioOutputDialog(
            context: ctx,
            ref: ref,
            currentOutput: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Audio Output'), findsOneWidget);
    });
  });

  // ── PassthroughCodecs dialog ──────────────────────────────
  //
  // The dialog renders 5 CheckboxListTiles plus quick-select chips,
  // which exceeds the default 800×600 test surface. Each test here
  // enlarges the surface to 800×1200 and restores it on teardown.

  group('PassthroughCodecs dialog', () {
    late _FakeSettingsNotifier fakeNotifier;

    // Surface size large enough to hold 5 codec checkboxes + chips.
    const tallSurface = Size(800, 1200);

    setUp(() {
      fakeNotifier = _FakeSettingsNotifier();
    });

    /// Opens the passthrough codecs dialog with [currentCodecs] selected.
    /// Enlarges the surface and registers a teardown to restore it.
    Future<void> pumpPassthrough(
      WidgetTester tester, {
      List<String> currentCodecs = const [],
    }) async {
      await tester.binding.setSurfaceSize(tallSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpDialogTrigger(
        tester,
        fakeNotifier,
        onTap: (ctx, ref) {
          showPassthroughCodecsDialog(
            context: ctx,
            ref: ref,
            currentCodecs: currentCodecs,
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders dialog title "Passthrough Codecs"', (tester) async {
      await pumpPassthrough(tester);

      expect(find.text('Passthrough Codecs'), findsOneWidget);
    });

    testWidgets('shows Dolby Family, DTS Family, and Clear All chips', (
      tester,
    ) async {
      await pumpPassthrough(tester);

      expect(find.text('Dolby Family'), findsOneWidget);
      expect(find.text('DTS Family'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
    });

    testWidgets('shows 5 individual codec checkboxes (excludes Atmos/DTS:X)', (
      tester,
    ) async {
      await pumpPassthrough(tester);

      // ac3, eac3, truehd, dts, dtsHd — atmos and dtsX are hidden.
      expect(find.byType(CheckboxListTile), findsNWidgets(5));
    });

    testWidgets('current codecs are pre-checked', (tester) async {
      await pumpPassthrough(tester, currentCodecs: const ['ac3', 'dts']);

      final ac3Tile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('Dolby Digital (AC3)'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(ac3Tile.value, isTrue);

      final dtsTile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('DTS'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(dtsTile.value, isTrue);
    });

    testWidgets('non-selected codecs start unchecked', (tester) async {
      await pumpPassthrough(tester, currentCodecs: const ['ac3']);

      final dtsTile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('DTS'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(dtsTile.value, isFalse);
    });

    testWidgets('Dolby Family chip checks AC3, EAC3, and TrueHD', (
      tester,
    ) async {
      await pumpPassthrough(tester);

      await tester.tap(find.text('Dolby Family'));
      await tester.pumpAndSettle();

      final ac3Tile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('Dolby Digital (AC3)'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(ac3Tile.value, isTrue);

      final eac3Tile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('Dolby Digital Plus'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(eac3Tile.value, isTrue);

      final truehdTile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('Dolby TrueHD'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(truehdTile.value, isTrue);
    });

    testWidgets('DTS Family chip checks DTS and DTS-HD Master Audio', (
      tester,
    ) async {
      await pumpPassthrough(tester);

      await tester.tap(find.text('DTS Family'));
      await tester.pumpAndSettle();

      final dtsTile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('DTS'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(dtsTile.value, isTrue);

      final dtsHdTile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('DTS-HD Master Audio'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(dtsHdTile.value, isTrue);
    });

    testWidgets('Clear All chip unchecks all codecs', (tester) async {
      await pumpPassthrough(
        tester,
        currentCodecs: const ['ac3', 'eac3', 'truehd', 'dts', 'dts-hd'],
      );

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // All 5 checkboxes should now be unchecked.
      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      for (final tile in tiles) {
        expect(tile.value, isFalse);
      }
    });

    testWidgets('tapping an unchecked codec checks it', (tester) async {
      await pumpPassthrough(tester, currentCodecs: const []);

      await tester.tap(
        find
            .ancestor(
              of: find.text('Dolby Digital (AC3)'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();

      final ac3Tile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('Dolby Digital (AC3)'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(ac3Tile.value, isTrue);
    });

    testWidgets('tapping a checked codec unchecks it', (tester) async {
      await pumpPassthrough(tester, currentCodecs: const ['ac3']);

      await tester.tap(
        find
            .ancestor(
              of: find.text('Dolby Digital (AC3)'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();

      final ac3Tile = tester.widget<CheckboxListTile>(
        find
            .ancestor(
              of: find.text('Dolby Digital (AC3)'),
              matching: find.byType(CheckboxListTile),
            )
            .first,
      );
      expect(ac3Tile.value, isFalse);
    });

    testWidgets('Apply button calls setAudioPassthroughCodecs', (tester) async {
      await pumpPassthrough(tester, currentCodecs: const ['ac3']);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastPassthroughCodecs, isNotNull);
      expect(fakeNotifier.lastPassthroughCodecs, contains('ac3'));
    });

    testWidgets('Apply with no codecs selected saves empty list', (
      tester,
    ) async {
      await pumpPassthrough(tester, currentCodecs: const []);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastPassthroughCodecs, isEmpty);
    });

    testWidgets('Apply button dismisses the dialog', (tester) async {
      await pumpPassthrough(tester, currentCodecs: const []);

      expect(find.text('Passthrough Codecs'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Passthrough Codecs'), findsNothing);
    });

    testWidgets('Cancel button closes dialog without calling setter', (
      tester,
    ) async {
      await pumpPassthrough(tester, currentCodecs: const ['ac3']);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastPassthroughCodecs, isNull);
      expect(find.text('Passthrough Codecs'), findsNothing);
    });

    testWidgets('Apply after Dolby Family saves AC3+EAC3+TrueHD mpv values', (
      tester,
    ) async {
      await pumpPassthrough(tester, currentCodecs: const []);

      await tester.tap(find.text('Dolby Family'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final saved = fakeNotifier.lastPassthroughCodecs!;
      // dolbyCodecs: ac3, eac3, truehd, atmos (atmos shares truehd mpvValue).
      for (final codec in PassthroughCodec.dolbyCodecs) {
        expect(saved, contains(codec.mpvValue));
      }
    });

    testWidgets('Apply after DTS Family saves DTS+DTS-HD mpv values', (
      tester,
    ) async {
      await pumpPassthrough(tester, currentCodecs: const []);

      await tester.tap(find.text('DTS Family'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final saved = fakeNotifier.lastPassthroughCodecs!;
      // dtsCodecs: dts, dtsHd, dtsX (dtsX shares dts-hd mpvValue).
      for (final codec in PassthroughCodec.dtsCodecs) {
        expect(saved, contains(codec.mpvValue));
      }
    });

    testWidgets('Apply after Clear All saves empty list', (tester) async {
      await pumpPassthrough(tester, currentCodecs: const ['ac3', 'dts']);

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastPassthroughCodecs, isEmpty);
    });
  });
}
