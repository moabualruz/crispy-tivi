import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;
import 'package:crispy_tivi/core/navigation/app_router.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
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

  // Settings persistence tests require an expanded desktop viewport:
  // wide enough for side navigation, but below the `large` breakpoint so
  // SettingsScreen still uses the tabbed content path exercised by the robot.
  // On Android,
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
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });

        await FfiTestHelper.setupSettingsBackendState();
        await app.main();
        await tester.pump(const Duration(milliseconds: 4000));

        final navRobot = NavigationRobot(tester);
        final settingsRobot = SettingsRobot(tester);

        // Navigate to Settings.
        await navRobot.waitForShell();
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(TestKeys.appShell)),
          listen: false,
        );
        container.read(goRouterProvider).go(AppRoutes.settings);
        await tester.pump(const Duration(milliseconds: 500));
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
        container.read(goRouterProvider).go(AppRoutes.home);
        await tester.pump(const Duration(milliseconds: 500));

        container.read(goRouterProvider).go(AppRoutes.settings);
        await tester.pump(const Duration(milliseconds: 500));
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
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });

        await FfiTestHelper.setupSettingsBackendState();
        await app.main();
        await tester.pump(const Duration(milliseconds: 4000));

        final navRobot = NavigationRobot(tester);
        final settingsRobot = SettingsRobot(tester);

        await navRobot.waitForShell();
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(TestKeys.appShell)),
          listen: false,
        );
        container.read(goRouterProvider).go(AppRoutes.settings);
        await tester.pump(const Duration(milliseconds: 500));
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
        container.read(goRouterProvider).go(AppRoutes.home);
        await tester.pump(const Duration(milliseconds: 500));

        container.read(goRouterProvider).go(AppRoutes.settings);
        await tester.pump(const Duration(milliseconds: 500));
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
