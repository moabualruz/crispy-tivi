// Tests for StillWatchingOverlay.
//
// Covers:
//   - Title text renders
//   - Episode count displays correctly
//   - "Continue Watching" button fires onContinue callback
//   - "I'm Done" button fires onDone callback

import 'package:crispy_tivi/features/player/presentation/widgets/still_watching_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────

Widget _wrap({
  int episodeCount = 3,
  VoidCallback? onContinue,
  VoidCallback? onDone,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            StillWatchingOverlay(
              episodeCount: episodeCount,
              onContinue: onContinue ?? () {},
              onDone: onDone ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  group('StillWatchingOverlay', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(_wrap());

      expect(find.text('Are You Still Watching?'), findsOneWidget);
    });

    testWidgets('shows episode count', (tester) async {
      await tester.pumpWidget(_wrap(episodeCount: 5));

      expect(find.text('5 episodes played automatically'), findsOneWidget);
    });

    testWidgets('Continue Watching button triggers callback', (tester) async {
      var callbackFired = false;
      await tester.pumpWidget(_wrap(onContinue: () => callbackFired = true));

      await tester.tap(find.text('Continue Watching'));
      expect(callbackFired, isTrue);
    });

    testWidgets("I'm Done button triggers callback", (tester) async {
      var callbackFired = false;
      await tester.pumpWidget(_wrap(onDone: () => callbackFired = true));

      await tester.tap(find.text("I'm Done"));
      expect(callbackFired, isTrue);
    });
  });
}
