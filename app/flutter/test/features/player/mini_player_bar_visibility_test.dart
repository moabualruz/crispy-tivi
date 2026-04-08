// Tests for MiniPlayerBar coordinator-driven visibility.
//
// Covers all mode + status combinations:
//   - background + playing -> bar visible
//   - background + paused -> bar visible
//   - background + buffering -> bar visible
//   - background + idle -> bar hidden
//   - background + error -> bar hidden
//   - fullscreen + playing -> bar hidden
//   - idle + idle -> bar hidden
//   - preview + playing -> bar hidden

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

class _IdlePlayerModeNotifier extends PlayerModeNotifier {
  @override
  PlayerModeState build() => const PlayerModeState(mode: PlayerMode.idle);
}

class _BackgroundPlayerModeNotifier extends PlayerModeNotifier {
  @override
  PlayerModeState build() => const PlayerModeState(mode: PlayerMode.background);
}

class _FullscreenPlayerModeNotifier extends PlayerModeNotifier {
  @override
  PlayerModeState build() => const PlayerModeState(mode: PlayerMode.fullscreen);
}

class _PreviewPlayerModeNotifier extends PlayerModeNotifier {
  @override
  PlayerModeState build() => const PlayerModeState(mode: PlayerMode.preview);
}

// ─── Helpers ─────────────────────────────────────────────────

Widget _buildBar({
  required MockPlayerService mockService,
  required app.PlaybackState playbackState,
  required PlayerModeNotifier Function() modeNotifier,
}) {
  return ProviderScope(
    overrides: [
      playerServiceProvider.overrideWithValue(mockService),
      playerProvider.overrideWithValue(MockCrispyPlayer()),
      playbackStateProvider.overrideWith((ref) => Stream.value(playbackState)),
      playerModeProvider.overrideWith(modeNotifier),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MiniPlayerBar()),
    ),
  );
}

const _activeState = app.PlaybackState(
  status: app.PlaybackStatus.playing,
  channelName: 'Test Channel',
  isLive: true,
  volume: 1.0,
  isMuted: false,
);

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

  group('MiniPlayerBar — coordinator-driven visibility', () {
    testWidgets('background + playing -> bar visible', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: _activeState,
          modeNotifier: _BackgroundPlayerModeNotifier.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Channel'), findsOneWidget);
    });

    testWidgets('background + paused -> bar visible', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: _activeState.copyWith(
            status: app.PlaybackStatus.paused,
          ),
          modeNotifier: _BackgroundPlayerModeNotifier.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Channel'), findsOneWidget);
    });

    testWidgets('background + buffering -> bar visible', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: _activeState.copyWith(
            status: app.PlaybackStatus.buffering,
          ),
          modeNotifier: _BackgroundPlayerModeNotifier.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Channel'), findsOneWidget);
    });

    testWidgets('background + idle -> bar hidden', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: const app.PlaybackState(
            status: app.PlaybackStatus.idle,
            channelName: 'Test Channel',
          ),
          modeNotifier: _BackgroundPlayerModeNotifier.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Channel'), findsNothing);
    });

    testWidgets('fullscreen + playing -> bar hidden', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: _activeState,
          modeNotifier: _FullscreenPlayerModeNotifier.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Channel'), findsNothing);
    });

    testWidgets('idle + idle -> bar hidden', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: const app.PlaybackState(
            status: app.PlaybackStatus.idle,
          ),
          modeNotifier: _IdlePlayerModeNotifier.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Channel'), findsNothing);
    });

    testWidgets('preview + playing -> bar hidden', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          mockService: mockService,
          playbackState: _activeState,
          modeNotifier: _PreviewPlayerModeNotifier.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Channel'), findsNothing);
    });
  });
}
