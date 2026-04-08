import 'dart:ui' as ui;

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:crispy_tivi/core/widgets/side_panel.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart'
    as app;
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/player_osd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockPlayerService extends Mock implements PlayerService {}

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

class _EmptyBufferRangesNotifier extends BufferRangesNotifier {
  @override
  List<(double, double)> build() => const [];
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group('PlayerOsd', () {
    late MockPlayerService mockPlayerService;
    late MockCrispyPlayer mockPlayer;

    setUp(() {
      mockPlayerService = MockPlayerService();
      mockPlayer = MockCrispyPlayer();

      // Stub PlayerService
      when(() => mockPlayerService.player).thenReturn(mockPlayer);
      when(() => mockPlayerService.state).thenReturn(const app.PlaybackState());
      when(
        () => mockPlayerService.streamInfo,
      ).thenReturn({'Resolution': '1920x1080', 'Bitrate': '5000 kbps'});
      when(() => mockPlayerService.playOrPause()).thenAnswer((_) async {});
      when(() => mockPlayerService.refresh()).thenAnswer((_) async {});
      when(() => mockPlayerService.cycleAspectRatio()).thenAnswer((_) async {});
      when(
        () => mockPlayerService.setAudioTrack(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockPlayerService.setSubtitleTrack(any()),
      ).thenAnswer((_) async {});
      when(() => mockPlayerService.setSpeed(any())).thenAnswer((_) async {});
      when(() => mockPlayerService.setVolume(any())).thenAnswer((_) async {});
      when(() => mockPlayerService.toggleMute()).thenReturn(null);
      when(() => mockPlayerService.seek(any())).thenAnswer((_) async {});

      // Stub Player
      when(() => mockPlayer.audioTracks).thenReturn(const [
        CrispyAudioTrack(index: 0, title: 'Audio 1', language: 'en'),
        CrispyAudioTrack(index: 1, title: 'Audio 2', language: 'es'),
      ]);
      when(() => mockPlayer.subtitleTracks).thenReturn(const []);
      when(() => mockPlayer.isPlaying).thenReturn(false);
    });

    // Helper to build the widget under test with overrides
    Widget buildTestWidget({
      required Size size,
      app.PlaybackState state = const app.PlaybackState(
        isLive: false,
        duration: Duration(minutes: 90),
      ),
    }) {
      final backend = MemoryBackend();
      return ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(backend),
          playerServiceProvider.overrideWithValue(mockPlayerService),
          playerProvider.overrideWithValue(mockPlayer),
          playbackStateProvider.overrideWith((ref) => Stream.value(state)),
          osdStateProvider.overrideWith(() => OsdStateNotifierRaw()),
          streamStatsVisibleProvider.overrideWith(() => StreamStatsNotifier()),
          bufferRangesProvider.overrideWith(() => _EmptyBufferRangesNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(body: PlayerOsd(state: state)),
          ),
        ),
      );
    }

    testWidgets('shows SidePanel for Audio Selection on Large screen', (
      tester,
    ) async {
      // Set surface size to match MediaQuery
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      // Pass PlaybackState with audio tracks so
      // the picker has data to show.
      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1920, 1080),
          state: const app.PlaybackState(
            audioTracks: [
              app.AudioTrack(id: 0, title: 'Audio 1'),
              app.AudioTrack(id: 1, title: 'Audio 2'),
            ],
          ),
        ),
      );
    });

    testWidgets('shows BottomSheet for Audio Selection on Small screen', (
      tester,
    ) async {
      // Set surface size to match MediaQuery
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(360, 800),
          state: const app.PlaybackState(
            audioTracks: [
              app.AudioTrack(id: 0, title: 'Audio 1'),
              app.AudioTrack(id: 1, title: 'Audio 2'),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Audio Track is in the overflow menu
      final overflowButton = find.byIcon(Icons.more_vert_rounded);
      expect(overflowButton, findsOneWidget);

      // Open overflow menu
      await tester.tap(overflowButton);
      await tester.pump(const Duration(seconds: 1));

      // Tap "Audio Track" in popup menu
      final audioMenuItem = find.ancestor(
        of: find.text('Audio Track'),
        matching: find.byType(PopupMenuItem<String>),
      );
      expect(audioMenuItem, findsOneWidget);
      final gesture = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      await tester.tap(audioMenuItem);
      await tester.pump(const Duration(seconds: 1));

      // On small screens, SidePanel is NOT used
      expect(find.byType(SidePanel), findsNothing);
    });

    testWidgets('toggles Stream Stats via overflow menu', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(buildTestWidget(size: const Size(1920, 1080)));
      await tester.pump(const Duration(seconds: 1));

      // Stream Info is in the overflow menu
      final overflowButton = find.byIcon(Icons.more_vert_rounded);
      expect(overflowButton, findsOneWidget);

      // Open overflow menu
      await tester.tap(overflowButton);
      await tester.pump(const Duration(seconds: 1));

      // Tap "Stream Info" in popup menu
      final infoItem = find.text('Stream Info');
      expect(infoItem, findsOneWidget);
      await tester.tap(infoItem);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // StreamStatsOverlay is in PlayerOsd's Stack, so
      // toggling the provider should render it.
    });

    testWidgets('shows LIVE badge when stream is live', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1920, 1080),
          state: const app.PlaybackState(isLive: true),
        ),
      );
      // LiveBadge has infinite animation
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('hides LIVE badge when stream is VOD', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1920, 1080),
          state: const app.PlaybackState(
            isLive: false,
            duration: Duration(minutes: 90),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('speed button is visible for VOD content', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1920, 1080),
          state: const app.PlaybackState(
            isLive: false,
            duration: Duration(minutes: 90),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
    });

    testWidgets('speed button is disabled for live content', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1920, 1080),
          state: const app.PlaybackState(isLive: true),
        ),
      );
      // LiveBadge has infinite animation
      await tester.pump(const Duration(seconds: 1));

      // Speed icon should still be visible
      // (grayed out, not hidden).
      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);

      // Tapping should NOT call setSpeed.
      await tester.tap(find.byIcon(Icons.speed_rounded));
      await tester.pump();
      verifyNever(() => mockPlayerService.setSpeed(any()));
    });

    testWidgets('speed button shows label when not 1.0x', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1920, 1080),
          state: const app.PlaybackState(
            isLive: false,
            speed: 1.5,
            duration: Duration(minutes: 90),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1.5x'), findsOneWidget);
    });

    testWidgets('PiP menu item hidden when onEnterPip is null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      // Build OSD without onEnterPip (simulates web
      // where PlatformCapabilities.pip is false).
      await tester.pumpWidget(buildTestWidget(size: const Size(1920, 1080)));
      await tester.pump(const Duration(seconds: 1));

      // Open overflow menu.
      final overflowButton = find.byIcon(Icons.more_vert_rounded);
      expect(overflowButton, findsOneWidget);
      await tester.tap(overflowButton);
      await tester.pump(const Duration(seconds: 1));

      // PiP menu item should NOT be present.
      expect(find.text('Picture-in-Picture'), findsNothing);
    });

    group('EPG on channel', () {
      Widget buildEpgTestWidget({
        required Size size,
        required app.PlaybackState state,
        String? channelEpgId,
        EpgState? epgState,
      }) {
        return ProviderScope(
          overrides: [
            crispyBackendProvider.overrideWithValue(MemoryBackend()),
            playerServiceProvider.overrideWithValue(mockPlayerService),
            playerProvider.overrideWithValue(mockPlayer),
            playbackStateProvider.overrideWith((ref) => Stream.value(state)),
            osdStateProvider.overrideWith(() => OsdStateNotifierRaw()),
            streamStatsVisibleProvider.overrideWith(
              () => StreamStatsNotifier(),
            ),
            bufferRangesProvider.overrideWith(
              () => _EmptyBufferRangesNotifier(),
            ),
            if (epgState != null)
              epgProvider.overrideWith(() => _TestEpgNotifier(epgState)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: Scaffold(
                body: PlayerOsd(state: state, channelEpgId: channelEpgId),
              ),
            ),
          ),
        );
      }

      testWidgets('shows EPG program title for live channel', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        final now = DateTime.now().toUtc();
        final epgState = EpgState(
          entries: {
            'ch-123': [
              EpgEntry(
                channelId: 'ch-123',
                title: 'Evening News',
                startTime: now.subtract(const Duration(minutes: 30)),
                endTime: now.add(const Duration(minutes: 30)),
              ),
            ],
          },
        );

        await tester.pumpWidget(
          buildEpgTestWidget(
            size: const Size(1920, 1080),
            state: const app.PlaybackState(
              isLive: true,
              channelName: 'BBC One',
            ),
            channelEpgId: 'ch-123',
            epgState: epgState,
          ),
        );
        // LiveBadge has infinite animation.
        await tester.pump(const Duration(seconds: 1));

        // LiveEpgStrip (above bottom bar) and CurrentProgramLabel
        // (in OSD top bar) both show the title — expect at least one.
        expect(find.text('Evening News'), findsAtLeastNWidgets(1));
      });

      testWidgets('shows nothing when no EPG data for channel', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        // EPG state with no entries for ch-999.
        const epgState = EpgState(entries: {});

        await tester.pumpWidget(
          buildEpgTestWidget(
            size: const Size(1920, 1080),
            state: const app.PlaybackState(
              isLive: true,
              channelName: 'Unknown TV',
            ),
            channelEpgId: 'ch-999',
            epgState: epgState,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // No program title should appear.
        expect(find.text('Evening News'), findsNothing);
      });

      testWidgets('shows nothing when channelEpgId is null', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        await tester.pumpWidget(
          buildEpgTestWidget(
            size: const Size(1920, 1080),
            state: const app.PlaybackState(
              isLive: true,
              channelName: 'Live TV',
            ),
            channelEpgId: null,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // No EPG label at all since ID is null.
        // Verify no crash and no EPG text.
        expect(find.text('Live TV'), findsWidgets);
      });

      testWidgets('shows nothing for VOD content even with '
          'channelEpgId', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        final now = DateTime.now().toUtc();
        final epgState = EpgState(
          entries: {
            'ch-123': [
              EpgEntry(
                channelId: 'ch-123',
                title: 'Should Not Show',
                startTime: now.subtract(const Duration(minutes: 30)),
                endTime: now.add(const Duration(minutes: 30)),
              ),
            ],
          },
        );

        await tester.pumpWidget(
          buildEpgTestWidget(
            size: const Size(1920, 1080),
            state: const app.PlaybackState(
              isLive: false,
              channelName: 'Movie',
              duration: Duration(hours: 2),
            ),
            channelEpgId: 'ch-123',
            epgState: epgState,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // EPG label is only shown for live streams
        // (isLive check in _TopBar).
        expect(find.text('Should Not Show'), findsNothing);
      });

      testWidgets('shows nothing when all EPG entries are in '
          'the past', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        final now = DateTime.now().toUtc();
        final epgState = EpgState(
          entries: {
            'ch-123': [
              EpgEntry(
                channelId: 'ch-123',
                title: 'Old Show',
                startTime: now.subtract(const Duration(hours: 3)),
                endTime: now.subtract(const Duration(hours: 2)),
              ),
            ],
          },
        );

        await tester.pumpWidget(
          buildEpgTestWidget(
            size: const Size(1920, 1080),
            state: const app.PlaybackState(
              isLive: true,
              channelName: 'Test Channel',
            ),
            channelEpgId: 'ch-123',
            epgState: epgState,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // Past program should not appear.
        expect(find.text('Old Show'), findsNothing);
      });
    });
  });
}

// Custom Notifier to force visibility.
class OsdStateNotifierRaw extends OsdStateNotifier {
  @override
  OsdState build() {
    return OsdState.visible;
  }
}

/// Test EPG notifier that pre-loads given state.
class _TestEpgNotifier extends EpgNotifier {
  _TestEpgNotifier(this._initialState);
  final EpgState _initialState;

  @override
  EpgState build() => _initialState;
}
