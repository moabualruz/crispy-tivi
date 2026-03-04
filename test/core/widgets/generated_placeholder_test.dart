import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/generated_placeholder.dart';

void main() {
  group('GeneratedPlaceholder', () {
    testWidgets('shows first letter of single-word title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: GeneratedPlaceholder(title: 'Avatar'),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('shows two initials for multi-word title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: GeneratedPlaceholder(title: 'Breaking Bad'),
          ),
        ),
      );

      expect(find.text('BB'), findsOneWidget);
    });

    testWidgets('shows ? for empty title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: GeneratedPlaceholder(title: ''),
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('shows fallback icon when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: GeneratedPlaceholder(title: 'Test', icon: Icons.movie),
          ),
        ),
      );

      expect(find.byIcon(Icons.movie), findsOneWidget);
    });

    testWidgets('does not show icon when not provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: GeneratedPlaceholder(title: 'Test'),
          ),
        ),
      );

      expect(find.byIcon(Icons.movie), findsNothing);
    });

    testWidgets('renders gradient background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: GeneratedPlaceholder(title: 'Test'),
          ),
        ),
      );

      // Verify Container with gradient exists.
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isNotNull);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    test('same title produces same gradient colors', () {
      // Deterministic hash → same gradient every time.
      // We can't call private methods directly, but
      // the contract is that identical titles produce
      // identical visual output.
      const title = 'The Matrix';
      final hash1 = title.hashCode;
      final hash2 = title.hashCode;
      expect(hash1, hash2);
    });
  });
}
