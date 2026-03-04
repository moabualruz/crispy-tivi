import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crispy_tivi/core/widgets/cinematic_hero_banner.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.push('/banner'),
                    child: const Text('Go'),
                  ),
                ),
              ),
        ),
        GoRoute(
          path: '/banner',
          builder:
              (context, state) =>
                  Scaffold(body: CustomScrollView(slivers: [child])),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  group('CinematicHeroBanner', () {
    testWidgets('renders all provided components', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const CinematicHeroBanner(
            heroTag: 'test-hero',
            image: Text('Test Image'),
            titleColumn: Text('Test Title'),
          ),
        ),
      );

      // Navigate to banner
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Test Image'), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);
      final heroWidget = tester.widget<Hero>(heroFinder);
      expect(heroWidget.tag, 'test-hero');
    });

    testWidgets('back button pops route', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const CinematicHeroBanner(
            heroTag: 'test-hero',
            image: SizedBox(),
            titleColumn: SizedBox(),
          ),
        ),
      );

      // Navigate to banner
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.byType(CinematicHeroBanner), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Banner should be gone
      expect(find.byType(CinematicHeroBanner), findsNothing);
      expect(find.text('Go'), findsOneWidget);
    });
  });
}
