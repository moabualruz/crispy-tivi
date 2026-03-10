import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/recording_profile.dart';
import 'package:crispy_tivi/features/player/domain/entities/stream_profile.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'playback_selection_dialogs.dart';

// ── Minimal AppConfig for tests ─────────────────────────────
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

// ── Fake SettingsNotifier ────────────────────────────────────
class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  String? lastAspectRatio;
  String? lastStreamProfile;
  String? lastRecordingProfile;
  String? lastExternalPlayer;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());

  @override
  Future<void> setAspectRatio(String ratio) async {
    lastAspectRatio = ratio;
  }

  @override
  Future<void> setStreamProfile(String profile) async {
    lastStreamProfile = profile;
  }

  @override
  Future<void> setRecordingProfile(String profile) async {
    lastRecordingProfile = profile;
  }

  @override
  Future<void> setExternalPlayer(String player) async {
    lastExternalPlayer = player;
  }

  // Stubs for remaining SettingsNotifier methods.
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakeSettingsNotifier fakeNotifier;

  setUp(() {
    fakeNotifier = _FakeSettingsNotifier();
  });

  /// Pumps a scaffold with a button that opens a dialog when tapped.
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

  // ── showAspectRatioDialog ──────────────────────────────────

  group('showAspectRatioDialog', () {
    const aspectOptions = ['Auto', '16:9', '4:3', 'Fill'];

    testWidgets('displays all 4 aspect ratio options', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAspectRatioDialog(
            context: ctx,
            ref: ref,
            currentRatio: 'Auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final option in aspectOptions) {
        expect(find.text(option), findsOneWidget);
      }
    });

    testWidgets('shows dialog title "Aspect Ratio"', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAspectRatioDialog(
            context: ctx,
            ref: ref,
            currentRatio: '16:9',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Aspect Ratio'), findsOneWidget);
    });

    testWidgets('highlights current selection with checked icon', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAspectRatioDialog(
            context: ctx,
            ref: ref,
            currentRatio: '4:3',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // One checked radio for the current selection, three unchecked.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(aspectOptions.length - 1),
      );
    });

    testWidgets('tapping an option calls setAspectRatio', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAspectRatioDialog(
            context: ctx,
            ref: ref,
            currentRatio: 'Auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fill'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastAspectRatio, 'Fill');
    });

    testWidgets('dialog closes after selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showAspectRatioDialog(
            context: ctx,
            ref: ref,
            currentRatio: '16:9',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Aspect Ratio'), findsOneWidget);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();

      expect(find.text('Aspect Ratio'), findsNothing);
    });
  });

  // ── showStreamProfileDialog ────────────────────────────────

  group('showStreamProfileDialog', () {
    testWidgets('displays all StreamProfile options', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showStreamProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final profile in StreamProfile.values) {
        expect(find.text(profile.label), findsOneWidget);
      }
    });

    testWidgets('shows StreamProfile descriptions', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showStreamProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final profile in StreamProfile.values) {
        expect(find.text(profile.description), findsOneWidget);
      }
    });

    testWidgets('shows dialog title "Stream Quality"', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showStreamProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Stream Quality'), findsOneWidget);
    });

    testWidgets('highlights current selection with checked icon', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showStreamProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'medium',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(StreamProfile.values.length - 1),
      );
    });

    testWidgets('tapping an option calls setStreamProfile with name', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showStreamProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(StreamProfile.high.label));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastStreamProfile, StreamProfile.high.name);
    });

    testWidgets('dialog closes after selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showStreamProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'auto',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Stream Quality'), findsOneWidget);

      await tester.tap(find.text(StreamProfile.low.label));
      await tester.pumpAndSettle();

      expect(find.text('Stream Quality'), findsNothing);
    });

    testWidgets('unknown profile name falls back to StreamProfile.auto', (
      tester,
    ) async {
      // Should not throw; orElse: () => StreamProfile.auto handles it.
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showStreamProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'unknownProfile',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog opened without crashing; auto is highlighted.
      expect(find.text('Stream Quality'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });
  });

  // ── showRecordingProfileDialog ─────────────────────────────

  group('showRecordingProfileDialog', () {
    testWidgets('displays all RecordingProfile options', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showRecordingProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'original',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final profile in RecordingProfile.values) {
        expect(find.text(profile.label), findsOneWidget);
      }
    });

    testWidgets('shows descriptions with GB/hr estimates', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showRecordingProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'original',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final profile in RecordingProfile.values) {
        final expectedDesc =
            '${profile.description} (${profile.estimatedSizePerHour})';
        expect(find.text(expectedDesc), findsOneWidget);
      }
    });

    testWidgets('shows dialog title "Recording Quality"', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showRecordingProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'original',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Recording Quality'), findsOneWidget);
    });

    testWidgets('highlights current selection with checked icon', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showRecordingProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'high',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(RecordingProfile.values.length - 1),
      );
    });

    testWidgets('tapping an option calls setRecordingProfile with name', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showRecordingProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'original',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(RecordingProfile.medium.label));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastRecordingProfile, RecordingProfile.medium.name);
    });

    testWidgets('dialog closes after selection', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showRecordingProfileDialog(
            context: ctx,
            ref: ref,
            currentProfile: 'original',
            isMounted: () => true,
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Recording Quality'), findsOneWidget);

      await tester.tap(find.text(RecordingProfile.low.label));
      await tester.pumpAndSettle();

      expect(find.text('Recording Quality'), findsNothing);
    });

    testWidgets(
      'unknown profile name falls back to RecordingProfile.original',
      (tester) async {
        await pumpDialogTrigger(
          tester,
          onTap: (ctx, ref) {
            showRecordingProfileDialog(
              context: ctx,
              ref: ref,
              currentProfile: 'unknownProfile',
              isMounted: () => true,
            );
          },
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Recording Quality'), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      },
    );
  });

  // ── showExternalPlayerDialog ───────────────────────────────

  group('showExternalPlayerDialog', () {
    // The full option list from the production dialog.
    const allPlayerLabels = [
      'Built-in (Default)',
      'System Default',
      'VLC',
      'MX Player',
      'MX Player Pro',
      'Kodi',
      'Just Player',
      'mpv',
      'IINA',
      'PotPlayer',
      'Celluloid',
      'Infuse',
    ];

    testWidgets('displays all player options including Built-in', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'none',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final label in allPlayerLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows dialog title "External Player"', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'none',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('External Player'), findsOneWidget);
    });

    testWidgets('highlights current player with checked icon', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'vlc',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(allPlayerLabels.length - 1),
      );
    });

    testWidgets('tapping "Built-in" calls setExternalPlayer with "none"', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'vlc',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Built-in (Default)'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastExternalPlayer, 'none');
    });

    testWidgets('tapping VLC calls setExternalPlayer with "vlc"', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'none',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('VLC'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastExternalPlayer, 'vlc');
    });

    testWidgets('tapping MX Player calls setExternalPlayer with "mxPlayer"', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'none',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('MX Player'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastExternalPlayer, 'mxPlayer');
    });

    testWidgets('dialog closes after selecting a player', (tester) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'none',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('External Player'), findsOneWidget);

      await tester.tap(find.text('Kodi'));
      await tester.pumpAndSettle();

      expect(find.text('External Player'), findsNothing);
    });

    testWidgets('Built-in is highlighted when currentPlayer is "none"', (
      tester,
    ) async {
      await pumpDialogTrigger(
        tester,
        onTap: (ctx, ref) {
          showExternalPlayerDialog(
            context: ctx,
            ref: ref,
            currentPlayer: 'none',
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // "none" maps to "Built-in (Default)" — it should be checked.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });
  });
}
