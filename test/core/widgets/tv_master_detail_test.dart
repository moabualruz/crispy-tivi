import 'package:crispy_tivi/core/widgets/tv_master_detail_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TvMasterDetailLayout', () {
    testWidgets('renders master panel full-width by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvMasterDetailLayout(
              masterPanel: const Text('master'),
              detailPanel: const Text('detail'),
            ),
          ),
        ),
      );

      // Master is always rendered (full-width via Positioned.fill).
      expect(find.text('master'), findsOneWidget);
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('hides detail panel when showDetail is false (default)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvMasterDetailLayout(
              masterPanel: const Text('master'),
              detailPanel: const Text('detail'),
            ),
          ),
        ),
      );

      // Detail is hidden by default (showDetail=false).
      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsNothing);
    });

    testWidgets('shows detail panel when showDetail is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvMasterDetailLayout(
              masterPanel: const Text('master'),
              detailPanel: const Text('detail'),
              showDetail: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('uses SlideTransition for detail panel animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvMasterDetailLayout(
              masterPanel: const Text('master'),
              detailPanel: const Text('detail'),
              showDetail: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find SlideTransition that is a descendant of TvMasterDetailLayout.
      expect(
        find.descendant(
          of: find.byType(TvMasterDetailLayout),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('accepts custom detailWidthFraction', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvMasterDetailLayout(
              masterPanel: const Text('master'),
              detailPanel: const Text('detail'),
              showDetail: true,
              detailWidthFraction: 0.6,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Detail panel should be visible at 60% width.
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('master takes full width when detail is hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvMasterDetailLayout(
              masterPanel: const Text('master'),
              detailPanel: const Text('detail'),
              showDetail: false,
            ),
          ),
        ),
      );

      // Master is always full-width via Positioned.fill.
      expect(find.text('master'), findsOneWidget);
      // No SlideTransition within TvMasterDetailLayout when detail is hidden.
      expect(
        find.descendant(
          of: find.byType(TvMasterDetailLayout),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('animates detail panel in when showDetail changes to true', (
      tester,
    ) async {
      var showDetail = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => showDetail = true),
                      child: const Text('show'),
                    ),
                    Expanded(
                      child: TvMasterDetailLayout(
                        masterPanel: const Text('master'),
                        detailPanel: const Text('detail'),
                        showDetail: showDetail,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // Detail is hidden initially.
      expect(find.text('detail'), findsNothing);

      // Trigger showDetail = true.
      await tester.tap(find.text('show'));
      await tester.pump();

      // Midway through animation — detail should start appearing.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('detail'), findsOneWidget);

      // Complete the animation.
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TvMasterDetailLayout),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
    });
  });
}
