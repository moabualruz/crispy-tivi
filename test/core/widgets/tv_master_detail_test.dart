import 'package:crispy_tivi/core/widgets/tv_master_detail_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TvMasterDetailLayout', () {
    testWidgets('renders Row with masterPanel and detailPanel', (tester) async {
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

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('has VerticalDivider between panels', (tester) async {
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

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('master is flex=2, detail is flex=3 (40/60 split)', (
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

      final expandedWidgets = tester.widgetList<Expanded>(
        find.byType(Expanded),
      );
      final flexValues = expandedWidgets.map((e) => e.flex).toList();

      // Default: masterFlex=2, detailFlex=3 — scaled by 1000 for animation.
      // Master = 2000, Detail = 3000 → 40/60 ratio preserved.
      expect(flexValues, contains(2000));
      expect(flexValues, contains(3000));
    });

    testWidgets('accepts custom flex values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvMasterDetailLayout(
              masterPanel: const Text('master'),
              detailPanel: const Text('detail'),
              masterFlex: 1,
              detailFlex: 1,
            ),
          ),
        ),
      );

      final expandedWidgets = tester.widgetList<Expanded>(
        find.byType(Expanded),
      );
      final flexValues = expandedWidgets.map((e) => e.flex).toList();

      // Both flex=1 → scaled: master=1000, detail=1000
      expect(flexValues.where((f) => f == 1000).length, 2);
    });

    testWidgets('hides detail panel when showDetail is false', (tester) async {
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

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
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

      final expandedWidgets = tester.widgetList<Expanded>(
        find.byType(Expanded),
      );
      // Only one Expanded — the master panel.
      expect(expandedWidgets.length, 1);
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
      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });
}
