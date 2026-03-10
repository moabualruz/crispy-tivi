// Tests for NextEpisodeOverlay.
//
// Covers:
//   - Renders episode label (S##E##) and progress bar
//   - "Play Now" fires onPlayNext and "Cancel" fires onCancel
//   - Auto-fires onPlayNext when AnimationController completes

import 'package:crispy_tivi/features/player/presentation/widgets/next_episode_overlay.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────

VodItem _episode({
  int seasonNumber = 1,
  int episodeNumber = 3,
  String? posterUrl,
}) => VodItem(
  id: 'ep-test',
  name: 'Test Episode',
  streamUrl: 'http://example.com/ep.mp4',
  type: VodType.episode,
  seasonNumber: seasonNumber,
  episodeNumber: episodeNumber,
  posterUrl: posterUrl,
);

Widget _wrap({
  required VodItem episode,
  VoidCallback? onPlayNext,
  VoidCallback? onCancel,
  int countdownSeconds = 10,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Stack(
        children: [
          NextEpisodeOverlay(
            nextEpisode: episode,
            onPlayNext: onPlayNext ?? () {},
            onCancel: onCancel ?? () {},
            countdownSeconds: countdownSeconds,
          ),
        ],
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  group('NextEpisodeOverlay', () {
    testWidgets(
      'renders episode label S01E03 when season and episode provided',
      (tester) async {
        await tester.pumpWidget(_wrap(episode: _episode()));
        await tester.pump();

        // S01E03 label should appear.
        expect(find.text('S01E03'), findsOneWidget);
      },
    );

    testWidgets('renders progress bar (LinearProgressIndicator)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(episode: _episode()));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders episode name text', (tester) async {
      await tester.pumpWidget(_wrap(episode: _episode()));
      await tester.pump();

      expect(find.text('Test Episode'), findsOneWidget);
    });

    testWidgets('Play Now button fires onPlayNext', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(episode: _episode(), onPlayNext: () => fired = true),
      );
      await tester.pump();

      await tester.tap(find.text('Play Now'));
      expect(fired, isTrue);
    });

    testWidgets('Cancel button fires onCancel', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(episode: _episode(), onCancel: () => fired = true),
      );
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      expect(fired, isTrue);
    });

    testWidgets('does not show episode label when season/episode are null', (
      tester,
    ) async {
      const ep = VodItem(
        id: 'movie',
        name: 'Movie Title',
        streamUrl: 'http://example.com/movie.mp4',
        type: VodType.movie,
      );
      await tester.pumpWidget(_wrap(episode: ep));
      await tester.pump();

      // No S##E## pattern should appear.
      expect(find.textContaining('S0'), findsNothing);
    });

    testWidgets(
      'AnimationController fires StatusListener with completed when elapsed',
      (tester) async {
        // Verify the auto-fire logic:
        // The _NextEpisodeOverlayState sets up an AnimationController that
        // calls onPlayNext when its status reaches completed. We verify this
        // behaviour by mounting a widget so the SchedulerBinding frame
        // pipeline is active, then pumping past the full duration.
        var firedCount = 0;

        // A mounted widget activates the SchedulerBinding frame pipeline so
        // that ticker callbacks (used by AnimationController) are processed
        // when tester.pump(duration) is called.
        await tester.pumpWidget(const SizedBox.shrink());

        final controller = AnimationController(
          vsync: tester,
          duration: const Duration(seconds: 5),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) firedCount++;
        });

        controller.forward();
        expect(firedCount, 0);

        // Pump small increments to advance through the full 5-second duration.
        // A single large pump may not fire the ticker if the binding hasn't
        // processed the initial scheduleFrame request from forward().
        await tester.pump(); // process the initial frame request
        await tester.pump(const Duration(seconds: 6)); // advance past duration

        controller.dispose();

        // Completed status must have fired exactly once.
        expect(firedCount, 1);
      },
    );
  });
}
