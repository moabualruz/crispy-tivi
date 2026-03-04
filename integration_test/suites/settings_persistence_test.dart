import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../robots/navigation_robot.dart';
import '../robots/settings_robot.dart';
import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings & Persistence Suite', () {
    testWidgets('Toggle Theme -> Persistence check', (
      WidgetTester tester,
    ) async {
      await FfiTestHelper.setupSettingsBackendState();

      app.main();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final navRobot = NavigationRobot(tester);
      final settingsRobot = SettingsRobot(tester);

      await navRobot.waitForShell();
      await navRobot.tapSettings();

      await settingsRobot.waitForSettings();

      // Capture initial state
      final initialContext = tester.element(settingsRobot.settingsScreen);
      final initialBrightness = Theme.of(initialContext).brightness;
      final targetBrightness =
          initialBrightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark;

      await settingsRobot.toggleTheme();

      // Evaluate mid-flight changes
      final midContext = tester.element(settingsRobot.settingsScreen);
      settingsRobot.verifyThemeBrightness(
        Theme.of(midContext),
        targetBrightness,
      );

      // Simulate app restart to ensure persistance (reload UI)
      // In a real e2e, this relies on shared prefs or the internal KV store persisting
      // between fresh main calls.
      app.main();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final reloadedContext = tester.element(navRobot.appShell);
      expect(
        Theme.of(reloadedContext).brightness,
        targetBrightness,
        reason:
            'Brightness preference should persist after a simulated app restart.',
      );
    });
  });
}
