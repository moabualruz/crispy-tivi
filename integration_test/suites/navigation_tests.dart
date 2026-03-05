import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FfiTestHelper.ensureTestIsolation();
    await FfiTestHelper.seedTestSource();
  });
  tearDownAll(() => FfiTestHelper.cleanup());

  group('Navigation & Shell Architecture', () {
    testWidgets('Full Navigation & Shell Lifecycle Validation', (tester) async {
      // Boot application sequence once
      app.main();

      // Pump frames continuously until initial routing completes
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (tester.any(find.byKey(TestKeys.addProfileButton))) break;
        if (tester.any(find.byKey(TestKeys.navItem('Live TV')))) {
          break; // In case we skipped profile selection
        }
      }

      // Phase 2: Setup - Bypass Profile Selection if on a fresh database
      if (tester.any(find.byKey(TestKeys.addProfileButton))) {
        await tester.tap(find.byKey(TestKeys.addProfileButton));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500)); // Wait for dialog

        await tester.tap(find.text('Create Guest Profile'));
        // Pump until we land in the shell UI
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (tester.any(find.byKey(TestKeys.navItem('Live TV')))) break;
        }
      }

      // Phase 2: Test 1 - Basic Boot State (we should be in the AppShell now)
      expect(find.byType(MaterialApp), findsOneWidget);

      // Phase 2: Test 2 - Side navigation targets render correctly
      expect(find.byKey(TestKeys.navItem('Live TV')), findsOneWidget);
      expect(find.byKey(TestKeys.navItem('Movies')), findsOneWidget);
      expect(find.byKey(TestKeys.navItem('Series')), findsOneWidget);
      expect(find.byKey(TestKeys.navItem('Settings')), findsOneWidget);

      // Phase 2: Test 3 - Side navigation collapses correctly on constraints
      final drawerFinder = find.byType(AnimatedContainer).first;
      final size = tester.getSize(drawerFinder);
      expect(
        size.width,
        closeTo(72.0, 5.0),
        reason: "Icon-only rail should measure ~72dp initially",
      );

      // Phase 2: Test 4 - Clicking a route transitions gracefully without overlapping UI
      await tester.tap(find.byKey(TestKeys.navItem('Settings')));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byKey(TestKeys.settingsScreen), findsOneWidget);
    });
  });
}
