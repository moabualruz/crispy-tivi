import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'upscale_mode.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'upscale_quality.dart';
import 'package:crispy_tivi/features/settings/presentation/'
    'widgets/upscale_dialogs.dart';

// ── Minimal AppConfig for tests ───────────────────────
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

// ── Fake SettingsNotifier ─────────────────────────────
class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  String? lastUpscaleMode;
  String? lastUpscaleQuality;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());

  @override
  Future<void> setUpscaleMode(String mode) async {
    lastUpscaleMode = mode;
  }

  @override
  Future<void> setUpscaleQuality(String quality) async {
    lastUpscaleQuality = quality;
  }

  // Stubs for remaining SettingsNotifier methods
  // (not exercised by these tests).
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakeSettingsNotifier fakeNotifier;

  setUp(() {
    fakeNotifier = _FakeSettingsNotifier();
  });

  /// Pumps a scaffold that opens a dialog when tapped.
  Future<void> pumpDialogTrigger(
    WidgetTester tester, {
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

  // ── showUpscaleModeDialog ───────────────────────────

  group('showUpscaleModeDialog', () {
    testWidgets('displays all 4 mode options', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleModeDialog(
            context: ctx,
            ref: ref,
            currentMode: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final mode in UpscaleMode.values) {
        expect(find.text(mode.label), findsOneWidget);
        expect(find.text(mode.description), findsOneWidget);
      }
    });

    testWidgets('tapping an option calls setUpscaleMode', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleModeDialog(
            context: ctx,
            ref: ref,
            currentMode: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap "Force Software" option.
      await tester.tap(find.text(UpscaleMode.forceSoftware.label));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastUpscaleMode, UpscaleMode.forceSoftware.value);
    });

    testWidgets('highlights current mode with checked icon', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleModeDialog(
            context: ctx,
            ref: ref,
            currentMode: 'off',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // One checked radio for "off", three unchecked.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    });

    testWidgets('dialog closes after selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleModeDialog(
            context: ctx,
            ref: ref,
            currentMode: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify dialog is open.
      expect(find.text('Upscaling Mode'), findsOneWidget);

      // Tap an option.
      await tester.tap(find.text(UpscaleMode.off.label));
      await tester.pumpAndSettle();

      // Dialog should be closed.
      expect(find.text('Upscaling Mode'), findsNothing);
    });
  });

  // ── showUpscaleQualityDialog ────────────────────────

  group('showUpscaleQualityDialog', () {
    testWidgets('displays all 3 quality options', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleQualityDialog(
            context: ctx,
            ref: ref,
            currentQuality: 'balanced',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final q in UpscaleQuality.values) {
        expect(find.text(q.label), findsOneWidget);
        expect(find.text(q.description), findsOneWidget);
      }
    });

    testWidgets('tapping an option calls setUpscaleQuality', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleQualityDialog(
            context: ctx,
            ref: ref,
            currentQuality: 'balanced',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap "Maximum" option.
      await tester.tap(find.text(UpscaleQuality.maximum.label));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastUpscaleQuality, UpscaleQuality.maximum.value);
    });

    testWidgets('highlights current quality with checked icon', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleQualityDialog(
            context: ctx,
            ref: ref,
            currentQuality: 'performance',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // One checked radio for "performance",
      // two unchecked.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });

    testWidgets('dialog closes after selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showUpscaleQualityDialog(
            context: ctx,
            ref: ref,
            currentQuality: 'balanced',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Upscaling Quality'), findsOneWidget);

      await tester.tap(find.text(UpscaleQuality.performance.label));
      await tester.pumpAndSettle();

      expect(find.text('Upscaling Quality'), findsNothing);
    });
  });
}
