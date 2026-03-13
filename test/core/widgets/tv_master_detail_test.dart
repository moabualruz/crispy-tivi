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

      // Default: masterFlex=2, detailFlex=3
      expect(flexValues, contains(2));
      expect(flexValues, contains(3));
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

      expect(flexValues.where((f) => f == 1).length, 2);
    });
  });
}
