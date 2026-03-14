// Tests for MiniPlayerBar.
//
// Covers:
//   - Channel name text rendered
//   - LIVE badge visible when isLive=true; absent when false
//   - Play/Pause icon reflects isPlaying state
//   - Play/Pause tap calls playerService.playOrPause()
//   - Mute icon tap calls playerService.toggleMute()
//   - Close (x) tap calls playerService.stop()
//   - Bar hidden in fullscreen mode

import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart'
    as app;
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────

class MockPlayerService extends Mock implements PlayerService {}

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

// ─── Test-only PlayerMode notifiers ──────────────────────────

/// Background mode — MiniPlayerBar should show.
class _BackgroundPlayerModeNotifier extends PlayerModeNotifier {
  @override
  PlayerModeState build() => const PlayerModeState(mode: PlayerMode.background);
}

/// Fullscreen mode — MiniPlayerBar should hide itself.
class _FullscreenPlayerModeNotifier extends PlayerModeNotifier {
  @override
  PlayerModeState build() => const PlayerModeState(mode: PlayerMode.fullscreen);
}

// ─── Helpers ─────────────────────────────────────────────────

Widget _buildBar({
  required MockPlayerService mockService,
  app.PlaybackState playbackState = const app.PlaybackState(
    status: app.PlaybackStatus.playing,
    channelName: 'BBC News',
    isLive: true,
    volume: 1.0,
    isMuted: false,
  ),
  bool fullscreen = false,
}) {
  return ProviderScope(
    overrides: [
      playerServiceProvider.overrideWithValue(mockService),
      playerProvider.overrideWithValue(MockCrispyPlayer()),
      playbackStateProvider.overrideWith((ref) => Stream.value(playbackState)),
      playerModeProvider.overrideWith(
        fullscreen
            ? () => _FullscreenPlayerModeNotifier()
            : () => _BackgroundPlayerModeNotifier(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MiniPlayerBar()),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  late MockPlayerService mockService;

  setUp(() {
    mockService = MockPlayerService();
    when(() => mockService.playOrPause()).thenAnswer((_) async {});
    when(() => mockService.toggleMute()).thenReturn(null);
    when(() => mockService.stop()).thenAnswer((_) async {});
    when(() => mockService.forceStateEmit()).thenReturn(null);
    when(() => mockService.player).thenReturn(MockCrispyPlayer());
    when(
      () => mockService.stateStream,
    ).thenAnswer((_) => const Stream<app.PlaybackState>.empty());
    when(() => mockService.state).thenReturn(const app.PlaybackState());
  });

  group('MiniPlayerBar — visibility', () {
    testWidgets('bar is hidden in fullscreen mode', (tester) async {
      await tester.pumpWidget(
        _buildBar(mockService: mockService, fullscreen: true),
      );
      // Allow post-frame callbacks to settle.
      await tester.pump();
      await tester.pump();

      // Bar should not show its channel name when fullscreen.
      expect(find.text('BBC News'), findsNothing);
    });

    testWidgets('bar is visible in background mode with active playback', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBar(mockService: mockService));
      await tester.pump();
      await tester.pump();

      expect(find.text('BBC News'), findsOneWidget);
    });
  });

  group('MiniPlayerBar — channel name and LIVE badge', () {
    testWidgets('displays channel name text', (tester) async {
      await tester.pumpWidget(_buildBar(mockService: mockService));
      await tester.pump();
      await tester.pump();

      expect(find.text('BBC News'), findsOneWidget);
    });

    testWidgets('shows LIVE text when isLive=true', (tester) async {
      await tester.pumpWidget(_buildBar(mockService: mockService));
      await tester.pump();
      await tester.pump();

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('does not show LIVE text when isLive=false', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: const app.PlaybackState(
            status: app.PlaybackStatus.playing,
            channelName: 'Inception',
            isLive: false,
            volume: 1.0,
            isMuted: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('LIVE'), findsNothing);
    });
  });

  group('MiniPlayerBar — play/pause icon', () {
    testWidgets('shows pause icon when playing', (tester) async {
      await tester.pumpWidget(_buildBar(mockService: mockService));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('shows play icon when paused', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: const app.PlaybackState(
            status: app.PlaybackStatus.paused,
            channelName: 'CNN',
            isLive: true,
            volume: 1.0,
            isMuted: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });

  group('MiniPlayerBar — button interactions', () {
    testWidgets('tapping play/pause icon calls playOrPause', (tester) async {
      await tester.pumpWidget(_buildBar(mockService: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_rounded));
      verify(() => mockService.playOrPause()).called(1);
    });

    testWidgets('tapping mute icon (volume_up) calls toggleMute', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBar(mockService: mockService));
      await tester.pumpAndSettle();

      // Unmuted → volume_up icon shown.
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      verify(() => mockService.toggleMute()).called(1);
    });

    testWidgets('muted state shows volume_off icon', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: const app.PlaybackState(
            status: app.PlaybackStatus.playing,
            channelName: 'Sky Sports',
            isLive: true,
            volume: 0.0,
            isMuted: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('tapping close icon calls stop', (tester) async {
      await tester.pumpWidget(_buildBar(mockService: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      verify(() => mockService.stop()).called(1);
    });
  });
}
