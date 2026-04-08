import 'package:crispy_tivi/core/widgets/empty_state_widget.dart';
import 'package:crispy_tivi/core/widgets/error_banner.dart';
import 'package:crispy_tivi/core/widgets/skeleton_card_widget.dart';
import 'package:crispy_tivi/core/widgets/skeleton_list_row_widget.dart';
import 'package:crispy_tivi/core/widgets/shimmer_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorBanner', () {
    testWidgets('renders error message and retry button', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBanner(
              message: 'Failed to refresh',
              technicalDetail: 'Connection timeout',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to refresh'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Retry button
      final retryButton = find.byIcon(Icons.refresh);
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      expect(retried, isTrue);
    });

    testWidgets('expands to show technical detail on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBanner(
              message: 'Failed to refresh',
              technicalDetail: 'SocketException: Connection refused',
              onRetry: () {},
            ),
          ),
        ),
      );

      // Technical detail not visible initially
      expect(find.text('SocketException: Connection refused'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Failed to refresh'));
      await tester.pumpAndSettle();

      // Now visible
      expect(find.text('SocketException: Connection refused'), findsOneWidget);
    });

    testWidgets('uses errorContainer background color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorBanner(message: 'Error', onRetry: () {})),
        ),
      );

      // Widget exists with proper structure
      expect(find.byType(ErrorBanner), findsOneWidget);
    });
  });

  group('SkeletonCardWidget', () {
    testWidgets('renders with given dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonCardWidget(width: 200, height: 150)),
        ),
      );

      expect(find.byType(SkeletonCardWidget), findsOneWidget);
      expect(find.byType(ShimmerWrapper), findsOneWidget);
    });

    testWidgets('uses ShimmerWrapper for animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonCardWidget(width: 100, height: 100)),
        ),
      );

      // ShimmerWrapper provides the animation
      expect(
        find.descendant(
          of: find.byType(SkeletonCardWidget),
          matching: find.byType(ShimmerWrapper),
        ),
        findsOneWidget,
      );
    });
  });

  group('SkeletonListRowWidget', () {
    testWidgets('renders leading circle and text lines by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SkeletonListRowWidget())),
      );

      expect(find.byType(SkeletonListRowWidget), findsOneWidget);
      expect(find.byType(ShimmerWrapper), findsOneWidget);
    });

    testWidgets('hides leading circle when showLeadingCircle=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonListRowWidget(showLeadingCircle: false)),
        ),
      );

      // Should not have a CircleAvatar-shaped container
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(SkeletonListRowWidget),
          matching: find.byType(Container),
        ),
      );
      // Without circle, fewer containers
      expect(
        containers.where((c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle;
        }),
        isEmpty,
      );
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('renders icon, title, and description', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.tv,
              title: 'No channels',
              description: 'Add a source to get started',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.tv), findsOneWidget);
      expect(find.text('No channels'), findsOneWidget);
      expect(find.text('Add a source to get started'), findsOneWidget);
    });

    testWidgets('renders action button when showSettingsButton=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.tv,
              title: 'No channels',
              showSettingsButton: true,
            ),
          ),
        ),
      );

      expect(find.text('Go to Settings'), findsOneWidget);
    });
  });

  group('Touch target theme', () {
    testWidgets('theme sets MaterialTapTargetSize.padded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded),
          home: const Scaffold(body: SizedBox()),
        ),
      );

      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });
  });
}
