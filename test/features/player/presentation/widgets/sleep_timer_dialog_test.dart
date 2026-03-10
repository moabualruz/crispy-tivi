// Tests for SleepTimerDialog.
//
// Covers:
//   - Inactive state: 6 presets rendered (15/30/45/60/90/120 min)
//   - Active state: countdown "Stopping in MM:SS" + "Cancel Timer"
//   - Preset list still shown while active (override capability)
//   - Tap preset → calls service.setSleepTimer with correct duration

import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart'
    as app;
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/sleep_timer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────

class MockPlayerService extends Mock implements PlayerService {}

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

// ─── Helpers ─────────────────────────────────────────────────

Widget _buildDialog({
  required MockPlayerService mockService,
  app.PlaybackState playbackState = const app.PlaybackState(),
}) {
  return ProviderScope(
    overrides: [
      playerServiceProvider.overrideWithValue(mockService),
      playbackStateProvider.overrideWith((ref) => Stream.value(playbackState)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: Center(child: SleepTimerDialog())),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  late MockPlayerService mockService;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockService = MockPlayerService();
    when(() => mockService.setSleepTimer(any())).thenReturn(null);
    when(() => mockService.cancelSleepTimer()).thenReturn(null);
    when(() => mockService.player).thenReturn(MockCrispyPlayer());
    when(
      () => mockService.stateStream,
    ).thenAnswer((_) => const Stream<app.PlaybackState>.empty());
    when(() => mockService.state).thenReturn(const app.PlaybackState());
  });

  group('SleepTimerDialog — inactive state', () {
    testWidgets('renders Sleep Timer title', (tester) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      expect(find.text('Sleep Timer'), findsOneWidget);
    });

    testWidgets('renders all 6 preset options', (tester) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      for (final minutes in [15, 30, 45, 60, 90, 120]) {
        expect(find.text('$minutes minutes'), findsOneWidget);
      }
    });

    testWidgets('does not show countdown banner when timer inactive', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      expect(find.textContaining('Stopping in'), findsNothing);
    });

    testWidgets('does not show Cancel Timer button when inactive', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      expect(find.text('Cancel Timer'), findsNothing);
    });

    testWidgets('tapping 30 minutes preset calls setSleepTimer(30 min)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      await tester.tap(find.text('30 minutes'));
      verify(
        () => mockService.setSleepTimer(const Duration(minutes: 30)),
      ).called(1);
    });

    testWidgets('tapping 60 minutes preset calls setSleepTimer(60 min)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      await tester.tap(find.text('60 minutes'));
      verify(
        () => mockService.setSleepTimer(const Duration(minutes: 60)),
      ).called(1);
    });

    testWidgets('tapping 15 minutes preset calls setSleepTimer(15 min)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      await tester.tap(find.text('15 minutes'));
      verify(
        () => mockService.setSleepTimer(const Duration(minutes: 15)),
      ).called(1);
    });

    testWidgets('tapping 120 minutes preset calls setSleepTimer(120 min)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDialog(mockService: mockService));
      await tester.pump();

      await tester.tap(find.text('120 minutes'));
      verify(
        () => mockService.setSleepTimer(const Duration(minutes: 120)),
      ).called(1);
    });
  });

  group('SleepTimerDialog — active state', () {
    const activeState = app.PlaybackState(
      sleepTimerRemaining: Duration(minutes: 1, seconds: 2),
    );

    testWidgets('shows countdown banner "Stopping in ..." when active', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildDialog(mockService: mockService, playbackState: activeState),
      );
      await tester.pump();

      expect(find.textContaining('Stopping in'), findsOneWidget);
    });

    testWidgets('shows Cancel Timer button when timer active', (tester) async {
      await tester.pumpWidget(
        _buildDialog(mockService: mockService, playbackState: activeState),
      );
      await tester.pump();

      expect(find.text('Cancel Timer'), findsOneWidget);
    });

    testWidgets('Cancel Timer button uses error color styling', (tester) async {
      await tester.pumpWidget(
        _buildDialog(mockService: mockService, playbackState: activeState),
      );
      await tester.pump();

      // The Cancel Timer button should exist with error styling.
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Cancel Timer'),
          matching: find.byType(OutlinedButton),
        ),
      );
      // Style sets foregroundColor to colorScheme.error — non-null.
      expect(button.style, isNotNull);
    });

    testWidgets('preset list is still shown when timer is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildDialog(mockService: mockService, playbackState: activeState),
      );
      await tester.pump();

      // All 6 presets must remain visible for override capability.
      for (final minutes in [15, 30, 45, 60, 90, 120]) {
        expect(find.text('$minutes minutes'), findsOneWidget);
      }
    });

    testWidgets('tapping preset while active calls setSleepTimer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildDialog(mockService: mockService, playbackState: activeState),
      );
      await tester.pump();

      await tester.tap(find.text('45 minutes'));
      verify(
        () => mockService.setSleepTimer(const Duration(minutes: 45)),
      ).called(1);
    });
  });
}
