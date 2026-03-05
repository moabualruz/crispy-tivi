import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class SettingsRobot {
  final WidgetTester tester;

  SettingsRobot(this.tester);

  Finder get settingsScreen => find.byKey(TestKeys.settingsScreen);

  // TODO: Uncomment when dark mode toggle feature is implemented.
  // Finder get themeToggle => find.byKey(TestKeys.themeToggleSwitch);

  Future<void> waitForSettings() async {
    await tester.pumpUntilFound(settingsScreen);
  }

  // TODO: Re-enable when dark mode toggle feature is implemented.
  // Future<void> toggleTheme() async {
  //   await tester.pumpUntilFound(themeToggle);
  //   await tester.tap(themeToggle);
  //   // Pump to let the animation and state change finish
  //   await tester.pump(const Duration(milliseconds: 500));
  // }

  void verifyThemeBrightness(
    ThemeData themeData,
    Brightness expectedBrightness,
  ) {
    expect(
      themeData.brightness,
      expectedBrightness,
      reason: 'Theme brightness should match the expected toggled state.',
    );
  }
}
