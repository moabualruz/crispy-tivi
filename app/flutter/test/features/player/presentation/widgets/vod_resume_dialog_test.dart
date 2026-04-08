// Tests for the resume playback dialog (showResumeDialog).
//
// Covers:
//   - Title: "Resume Playback?"
//   - Position displayed as "Resume from 12:34"
//   - "Start Over" → returns false (caller interprets as Duration.zero)
//   - "Resume" → returns true (caller uses saved Duration)

import 'package:crispy_tivi/features/vod/presentation/widgets/episode_playback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────

/// Opens the resume dialog and returns the tester + a [Future<bool>]
/// representing the dialog result.
Future<bool?> _openDialog(WidgetTester tester, String formattedPosition) async {
  bool? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () async {
                  result = await showResumeDialog(context, formattedPosition);
                },
                child: const Text('Open'),
              ),
            ),
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();

  return result;
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  group('showResumeDialog', () {
    testWidgets('renders "Resume Playback?" as dialog title', (tester) async {
      await _openDialog(tester, '12:34');

      expect(find.text('Resume Playback?'), findsOneWidget);
    });

    testWidgets('displays formatted position "Resume from 12:34"', (
      tester,
    ) async {
      await _openDialog(tester, '12:34');

      expect(find.textContaining('Resume from 12:34'), findsOneWidget);
    });

    testWidgets('displays "Start Over" action button', (tester) async {
      await _openDialog(tester, '12:34');

      expect(find.text('Start Over'), findsOneWidget);
    });

    testWidgets('displays "Resume" action button', (tester) async {
      await _openDialog(tester, '12:34');

      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('"Start Over" returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () async {
                      result = await showResumeDialog(context, '1:23:45');
                    },
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Over'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('"Resume" returns true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () async {
                      result = await showResumeDialog(context, '12:34');
                    },
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('shows formatted position from 1h23m45s clock string', (
      tester,
    ) async {
      await _openDialog(tester, '1:23:45');

      expect(find.textContaining('1:23:45'), findsOneWidget);
    });

    testWidgets('dismissing dialog (barrier) returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () async {
                      result = await showResumeDialog(context, '5:00');
                    },
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // Tap outside the dialog to dismiss.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Null is treated as false by the caller (r ?? false).
      expect(result, isFalse);
    });
  });
}
