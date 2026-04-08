import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/player_osd/osd_sync_offset.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

void main() {
  late MockCrispyPlayer mockPlayer;

  setUp(() {
    mockPlayer = MockCrispyPlayer();
    // Default: no existing offset
    when(() => mockPlayer.getProperty('audio-delay')).thenReturn(null);
    when(() => mockPlayer.getProperty('sub-delay')).thenReturn(null);
    when(() => mockPlayer.setProperty(any(), any())).thenReturn(null);
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [playerProvider.overrideWithValue(mockPlayer)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SyncOffsetDialog()),
      ),
    );
  }

  group('SyncOffsetDialog', () {
    testWidgets('shows title and both rows', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Sync Offset'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows initial zero offsets', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Both should show +0.00 s
      expect(find.text('+0.00 s'), findsNWidgets(2));
    });

    testWidgets('reads existing offsets from player', (tester) async {
      when(() => mockPlayer.getProperty('audio-delay')).thenReturn('0.5');
      when(() => mockPlayer.getProperty('sub-delay')).thenReturn('-1.2');

      await tester.pumpWidget(buildTestWidget());

      expect(find.text('+0.50 s'), findsOneWidget); // audio
      expect(find.text('-1.20 s'), findsOneWidget); // sub
    });

    testWidgets('tap + button increments audio by 100ms', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Find the add buttons — there are 2 (audio + sub).
      // The first one is for audio.
      final addButtons = find.byIcon(Icons.add_rounded);
      expect(addButtons, findsNWidgets(2));

      await tester.tap(addButtons.first);
      await tester.pump();

      expect(find.text('+0.10 s'), findsOneWidget);
      verify(() => mockPlayer.setProperty('audio-delay', '0.1')).called(1);
    });

    testWidgets('tap - button decrements audio by 100ms', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final removeButtons = find.byIcon(Icons.remove_rounded);
      expect(removeButtons, findsNWidgets(2));

      await tester.tap(removeButtons.first);
      await tester.pump();

      expect(find.text('-0.10 s'), findsOneWidget);
      verify(() => mockPlayer.setProperty('audio-delay', '-0.1')).called(1);
    });

    testWidgets('tap + on subtitle increments sub-delay', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final addButtons = find.byIcon(Icons.add_rounded);
      await tester.tap(addButtons.last);
      await tester.pump();

      verify(() => mockPlayer.setProperty('sub-delay', '0.1')).called(1);
    });

    testWidgets('reset button appears and resets to 0', (tester) async {
      when(() => mockPlayer.getProperty('audio-delay')).thenReturn('0.5');

      await tester.pumpWidget(buildTestWidget());

      // Reset button should be visible for audio (non-zero).
      final resetButton = find.byTooltip('Reset to 0');
      expect(resetButton, findsOneWidget);

      await tester.tap(resetButton);
      await tester.pump();

      verify(() => mockPlayer.setProperty('audio-delay', '0.0')).called(1);
    });

    testWidgets('reset button hidden when offset is zero', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Both offsets are 0, so no reset buttons.
      expect(find.byTooltip('Reset to 0'), findsNothing);
    });

    testWidgets('offset clamped to ±60s', (tester) async {
      // Start at 59.95 s (just under 60 s).
      when(() => mockPlayer.getProperty('audio-delay')).thenReturn('59.95');

      await tester.pumpWidget(buildTestWidget());

      // Tap + to go past 60s — should clamp.
      final addButtons = find.byIcon(Icons.add_rounded);
      await tester.tap(addButtons.first);
      await tester.pump();

      // Should clamp to 60000 ms = 60.0 s.
      verify(() => mockPlayer.setProperty('audio-delay', '60.0')).called(1);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Sync Offset'), findsNothing);
    });

    testWidgets('slider is present for each row', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Slider), findsNWidgets(2));
    });
  });
}
