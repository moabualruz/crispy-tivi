import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;
import 'package:crispy_tivi/core/testing/test_keys.dart';

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

  // Settings persistence tests require a desktop-size viewport (1920x1080)
  // to render the full settings UI with side navigation.  On Android,
  // IntegrationTestWidgetsFlutterBinding ignores view size overrides
  // (the OS controls the window), so the app runs at the phone's native
  // compact layout where the settings content renders differently.
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;

  group('Settings Persistence Suite', () {
    testWidgets(
      'Auto-resume toggle persists across navigation',
      // Android: IntegrationTestWidgetsFlutterBinding ignores view size
      // overrides — the OS controls the window, so the app runs at the
      // phone's native compact layout where settings UI differs.
      skip: isAndroid,
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await FfiTestHelper.setupSettingsBackendState();
        app.main();
        await tester.pump(const Duration(milliseconds: 4000));

        final navRobot = NavigationRobot(tester);
        final settingsRobot = SettingsRobot(tester);

        // Navigate to Settings.
        await navRobot.waitForShell();
        await navRobot.tapSettings();
        await settingsRobot.waitForSettings();

        // Record the initial value (scrolls into view).
        const toggleLabel = 'Auto-resume last channel';
        final initialValue = await settingsRobot.getSwitchValue(toggleLabel);

        // Toggle it.
        await settingsRobot.toggleSwitch(toggleLabel);
        expect(
          await settingsRobot.getSwitchValue(toggleLabel),
          isNot(initialValue),
          reason: 'toggle should flip',
        );

        // Navigate away to Home, then back to Settings.
        // (Using Home instead of Live TV because Live TV can enter immersive mode and hide the nav rail)
        final homeNavItem = find.byKey(TestKeys.navItem('Home'));
        await tester.tap(homeNavItem.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));

        await navRobot.tapSettings();
        await settingsRobot.waitForSettings();

        // Verify persistence (scrolls into view again).
        expect(
          await settingsRobot.getSwitchValue(toggleLabel),
          isNot(initialValue),
          reason: 'toggled value should persist after navigation',
        );

        // Restore original value.
        await settingsRobot.toggleSwitch(toggleLabel);
      },
    );

    testWidgets(
      'Playback AFR toggle persists across navigation',
      // Android: IntegrationTestWidgetsFlutterBinding ignores view size
      // overrides — the OS controls the window, so the app runs at the
      // phone's native compact layout where settings UI differs.
      skip: isAndroid,
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await FfiTestHelper.setupSettingsBackendState();
        app.main();
        await tester.pump(const Duration(milliseconds: 4000));

        final navRobot = NavigationRobot(tester);
        final settingsRobot = SettingsRobot(tester);

        await navRobot.waitForShell();
        await navRobot.tapSettings();
        await settingsRobot.waitForSettings();

        // Switch to the Playback tab.
        await settingsRobot.tapTab('Playback');

        // Record initial value (scrolls into view).
        const toggleLabel = 'Auto Frame Rate';
        final initialValue = await settingsRobot.getSwitchValue(toggleLabel);

        // Toggle it.
        await settingsRobot.toggleSwitch(toggleLabel);
        expect(
          await settingsRobot.getSwitchValue(toggleLabel),
          isNot(initialValue),
          reason: 'toggle should flip',
        );

        // Navigate away to Home, then back to Settings.
        // (Using Home instead of Live TV because Live TV can enter immersive mode and hide the nav rail)
        final homeNavItem = find.byKey(TestKeys.navItem('Home'));
        await tester.tap(homeNavItem.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));

        await navRobot.tapSettings();
        await settingsRobot.waitForSettings();

        // Switch back to Playback tab.
        await settingsRobot.tapTab('Playback');

        // Verify persistence.
        expect(
          await settingsRobot.getSwitchValue(toggleLabel),
          isNot(initialValue),
          reason: 'AFR toggle should persist after navigation',
        );

        // Restore original value.
        await settingsRobot.toggleSwitch(toggleLabel);
      },
    );
  });
}
