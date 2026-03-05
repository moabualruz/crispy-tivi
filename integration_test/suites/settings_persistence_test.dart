import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../robots/navigation_robot.dart';
import '../robots/settings_robot.dart';
import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FfiTestHelper.ensureTestIsolation();
    await FfiTestHelper.seedTestSource();
  });
  tearDownAll(() => FfiTestHelper.cleanup());

  group('Settings Persistence Suite', () {
    testWidgets('Auto-resume toggle persists across navigation', (
      WidgetTester tester,
    ) async {
      await FfiTestHelper.setupSettingsBackendState();
      app.main();
      await tester.pump(const Duration(milliseconds: 500));

      final navRobot = NavigationRobot(tester);
      final settingsRobot = SettingsRobot(tester);

      // Navigate to Settings.
      await navRobot.waitForShell();
      await navRobot.tapSettings();

      await settingsRobot.waitForSettings();

      // Record the initial value.
      const toggleLabel = 'Auto-resume last channel';
      final initialValue = settingsRobot.getSwitchValue(toggleLabel);

      // Toggle it.
      await settingsRobot.toggleSwitch(toggleLabel);
      expect(
        settingsRobot.getSwitchValue(toggleLabel),
        isNot(initialValue),
        reason: 'toggle should flip',
      );

      // Navigate away to Home, then back to Settings.
      await navRobot.tapLiveTv();
      await tester.pump(const Duration(milliseconds: 500));

      await navRobot.tapSettings();
      await settingsRobot.waitForSettings();

      // Verify persistence.
      expect(
        settingsRobot.getSwitchValue(toggleLabel),
        isNot(initialValue),
        reason: 'toggled value should persist after navigation',
      );

      // Restore original value.
      await settingsRobot.toggleSwitch(toggleLabel);
    });

    testWidgets('Playback AFR toggle persists across navigation', (
      WidgetTester tester,
    ) async {
      await FfiTestHelper.setupSettingsBackendState();
      app.main();
      await tester.pump(const Duration(milliseconds: 500));

      final navRobot = NavigationRobot(tester);
      final settingsRobot = SettingsRobot(tester);

      await navRobot.waitForShell();
      await navRobot.tapSettings();
      await settingsRobot.waitForSettings();

      // Switch to the Playback tab.
      await settingsRobot.tapTab('Playback');

      // Record initial value.
      const toggleLabel = 'Auto Frame Rate';
      final initialValue = settingsRobot.getSwitchValue(toggleLabel);

      // Toggle it.
      await settingsRobot.toggleSwitch(toggleLabel);
      expect(
        settingsRobot.getSwitchValue(toggleLabel),
        isNot(initialValue),
        reason: 'toggle should flip',
      );

      // Navigate away and back.
      await navRobot.tapLiveTv();
      await tester.pump(const Duration(milliseconds: 500));

      await navRobot.tapSettings();
      await settingsRobot.waitForSettings();

      // Switch back to Playback tab.
      await settingsRobot.tapTab('Playback');

      // Verify persistence.
      expect(
        settingsRobot.getSwitchValue(toggleLabel),
        isNot(initialValue),
        reason: 'AFR toggle should persist after navigation',
      );

      // Restore original value.
      await settingsRobot.toggleSwitch(toggleLabel);
    });
  });
}
