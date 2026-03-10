// Tests for MovieCompletionOverlay.
//
// Covers:
//   - "Watch Again" and "Browse More" buttons present
//   - Both callbacks fire correctly on tap

import 'package:crispy_tivi/features/player/presentation/widgets/movie_completion_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────

Widget _wrap({
  String title = 'Inception',
  VoidCallback? onWatchAgain,
  VoidCallback? onBrowseMore,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          MovieCompletionOverlay(
            currentTitle: title,
            onWatchAgain: onWatchAgain ?? () {},
            onBrowseMore: onBrowseMore ?? () {},
          ),
        ],
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  group('MovieCompletionOverlay', () {
    testWidgets('renders "Watch Again" button', (tester) async {
      await tester.pumpWidget(_wrap());

      expect(find.text('Watch Again'), findsOneWidget);
    });

    testWidgets('renders "Browse More" button', (tester) async {
      await tester.pumpWidget(_wrap());

      expect(find.text('Browse More'), findsOneWidget);
    });

    testWidgets('renders current movie title', (tester) async {
      await tester.pumpWidget(_wrap(title: 'Inception'));

      expect(find.text('Inception'), findsOneWidget);
    });

    testWidgets('renders "Finished" header label', (tester) async {
      await tester.pumpWidget(_wrap());

      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets('Watch Again button fires onWatchAgain callback', (
      tester,
    ) async {
      var fired = false;
      await tester.pumpWidget(_wrap(onWatchAgain: () => fired = true));

      await tester.tap(find.text('Watch Again'));
      expect(fired, isTrue);
    });

    testWidgets('Browse More button fires onBrowseMore callback', (
      tester,
    ) async {
      var fired = false;
      await tester.pumpWidget(_wrap(onBrowseMore: () => fired = true));

      await tester.tap(find.text('Browse More'));
      expect(fired, isTrue);
    });

    testWidgets('only Watch Again fires when Watch Again tapped', (
      tester,
    ) async {
      var watchAgainFired = false;
      var browseMoreFired = false;
      await tester.pumpWidget(
        _wrap(
          onWatchAgain: () => watchAgainFired = true,
          onBrowseMore: () => browseMoreFired = true,
        ),
      );

      await tester.tap(find.text('Watch Again'));
      expect(watchAgainFired, isTrue);
      expect(browseMoreFired, isFalse);
    });

    testWidgets('only Browse More fires when Browse More tapped', (
      tester,
    ) async {
      var watchAgainFired = false;
      var browseMoreFired = false;
      await tester.pumpWidget(
        _wrap(
          onWatchAgain: () => watchAgainFired = true,
          onBrowseMore: () => browseMoreFired = true,
        ),
      );

      await tester.tap(find.text('Browse More'));
      expect(watchAgainFired, isFalse);
      expect(browseMoreFired, isTrue);
    });
  });
}
