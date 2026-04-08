import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/shimmer_wrapper.dart';
import 'package:crispy_tivi/core/widgets/skeleton_loader.dart';

void main() {
  group('SkeletonLoader', () {
    testWidgets('renders with given width and height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: SkeletonLoader(width: 100, height: 50)),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, 100);
      expect(container.constraints?.maxHeight, 50);
    });

    testWidgets('wraps child in ShimmerWrapper', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: SkeletonLoader(width: 100, height: 50)),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(ShimmerWrapper), findsOneWidget);

      // Pump a few frames — shimmer animation should be running.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShimmerWrapper), findsOneWidget);
    });
  });

  group('SkeletonCard', () {
    testWidgets('renders with default 2:3 aspect ratio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: SkeletonCard())),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('accepts custom width and aspect ratio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: SkeletonCard(width: 200, aspectRatio: 16 / 9)),
        ),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
    });
  });

  group('SkeletonLine', () {
    testWidgets('renders with defaults', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: SkeletonLine())),
      );

      expect(find.byType(SkeletonLine), findsOneWidget);
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });
  });

  group('SkeletonAvatar', () {
    testWidgets('renders with defaults', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: SkeletonAvatar())),
      );

      expect(find.byType(SkeletonAvatar), findsOneWidget);
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });
  });
}
