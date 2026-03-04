import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:crispy_tivi/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation & Shell Architecture', () {
    testWidgets('Full Navigation & Shell Lifecycle Validation', (tester) async {
      // Boot application sequence once
      app.main();

      // Pump frames continuously until initial routing completes
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (tester.any(find.text('Add Profile'))) break;
        if (tester.any(find.byKey(const ValueKey('nav_item_live tv')))) {
          break; // In case we skipped profile selection
        }
      }

      // Phase 2: Setup - Bypass Profile Selection if on a fresh database
      if (tester.any(find.text('Add Profile'))) {
        await tester.tap(find.text('Add Profile'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500)); // Wait for dialog

        await tester.tap(find.text('Create Guest Profile'));
        // Pump until we land in the shell UI
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (tester.any(find.byKey(const ValueKey('nav_item_live tv')))) break;
        }
      }

      // Phase 2: Test 1 - Basic Boot State (we should be in the AppShell now)
      expect(find.byType(MaterialApp), findsOneWidget);

      // Phase 2: Test 2 - Side navigation targets render correctly
      expect(find.byKey(const ValueKey('nav_item_live tv')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_item_movies')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_item_series')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_item_settings')), findsOneWidget);

      // Phase 2: Test 3 - Side navigation collapses correctly on constraints
      final drawerFinder = find.byType(AnimatedContainer).first;
      final size = tester.getSize(drawerFinder);
      expect(
        size.width,
        closeTo(72.0, 5.0),
        reason: "Icon-only rail should measure ~72dp initially",
      );

      // Phase 2: Test 4 - Clicking a route transitions gracefully without overlapping UI
      await tester.tap(find.byKey(const ValueKey('nav_item_settings')));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Settings'), findsWidgets);
    });
  });
}
