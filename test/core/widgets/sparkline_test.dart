import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/sparkline.dart';

void main() {
  group('Sparkline', () {
    testWidgets('renders with empty samples', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Sparkline(samples: []))),
      );

      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('renders with single sample', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Sparkline(samples: [50.0]))),
      );

      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('renders with 30 samples at correct size', (tester) async {
      final samples = List.generate(30, (i) => i * 3.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Sparkline(samples: samples, width: 80, height: 24),
            ),
          ),
        ),
      );

      expect(find.byType(Sparkline), findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(find.byType(Sparkline));
      expect(renderBox.size, const Size(80, 24));
    });

    testWidgets('renders with all values below low threshold', (tester) async {
      final samples = List.generate(10, (i) => 5.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Sparkline(
              samples: samples,
              lowThreshold: 20,
              highThreshold: 60,
            ),
          ),
        ),
      );

      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('renders with all values above high threshold', (tester) async {
      final samples = List.generate(10, (i) => 80.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Sparkline(
              samples: samples,
              lowThreshold: 20,
              highThreshold: 60,
            ),
          ),
        ),
      );

      expect(find.byType(Sparkline), findsOneWidget);
    });

    testWidgets('custom min/max clamping', (tester) async {
      // Values outside the range should be clamped.
      const samples = [-10.0, 50.0, 150.0];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Sparkline(samples: samples, minValue: 0, maxValue: 100),
          ),
        ),
      );

      expect(find.byType(Sparkline), findsOneWidget);
    });
  });
}
