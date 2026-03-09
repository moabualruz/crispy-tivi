import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/media_query_scaler.dart';

void main() {
  group('MediaQueryScaler', () {
    testWidgets('passes through child when disabled', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(800, 600)),
          child: MediaQueryScaler(enable: false, child: _SizeReporter()),
        ),
      );

      // Should not find a FittedBox when disabled.
      expect(find.byType(FittedBox), findsNothing);
    });

    testWidgets('wraps in FittedBox when enabled', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(800, 600)),
          child: MediaQueryScaler(enable: true, child: _SizeReporter()),
        ),
      );

      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('applies custom scale factor', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(800, 600)),
          child: MediaQueryScaler(
            enable: true,
            scale: 2.0,
            child: _SizeReporter(),
          ),
        ),
      );

      // The SizedBox inside should have doubled dimensions.
      final sizedBox = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((sb) => sb.width == 1600 && sb.height == 1200);
      expect(sizedBox, isNotEmpty);
    });

    testWidgets('default scale is 1.3', (tester) async {
      const scaler = MediaQueryScaler(enable: true, child: SizedBox());
      expect(scaler.scale, 1.3);
    });
  });
}

/// Simple widget that renders nothing — just participates in the tree.
class _SizeReporter extends StatelessWidget {
  const _SizeReporter();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
