import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/widgets/responsive_layout.dart';
import 'package:crispy_tivi/core/widgets/ui_auto_scale.dart';

void main() {
  Widget buildAppWithWidth(double width, {double scale = 1.0}) {
    return MaterialApp(
      home: Scaffold(
        body: UiAutoScale(
          scale: scale,
          child: Center(
            child: SizedBox(
              width: width,
              child: const ResponsiveLayout(
                compactBody: Text('Compact'),
                mediumBody: Text('Medium'),
                expandedBody: Text('Expanded'),
                largeBody: Text('Large'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ResponsiveLayout', () {
    testWidgets('renders compact body < 600', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildAppWithWidth(500));
      expect(find.text('Compact'), findsOneWidget);
    });

    testWidgets('renders medium body 600 - 839', (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildAppWithWidth(700));
      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('renders expanded body 840 - 1199', (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildAppWithWidth(900));
      expect(find.text('Expanded'), findsOneWidget);
    });

    testWidgets('renders large body >= 1200 with padding', (tester) async {
      tester.view.physicalSize = const Size(1300, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildAppWithWidth(1300));
      expect(find.text('Large'), findsOneWidget);

      // Large layout wraps the body with overscan padding
      final paddingFinder =
          find
              .ancestor(of: find.text('Large'), matching: find.byType(Padding))
              .first;

      final paddingWidget = tester.widget<Padding>(paddingFinder);
      expect(
        paddingWidget.padding,
        equals(ResponsiveLayout.kTvOverscanPadding),
      );
    });

    testWidgets('scales width before checking layout class', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Width is 500, but scale is 2.4. Effective width = 1200.
      await tester.pumpWidget(buildAppWithWidth(500, scale: 2.4));
      expect(find.text('Large'), findsOneWidget);
    });
  });

  group('LayoutContext Extension', () {
    Widget buildContextTester(
      double width,
      void Function(BuildContext) onContext,
    ) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: Builder(
              builder: (context) {
                onContext(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('exposes layout properties', (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildContextTester(1000, (context) {
          expect(context.isCompact, isFalse);
          expect(context.isExpanded, isTrue); // 1000 is between 840 and 1199
          expect(context.layoutClass, LayoutClass.expanded);
          expect(context.usesSideNav, isTrue);
        }),
      );
    });
  });
}
