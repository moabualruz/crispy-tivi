import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class SettingsRobot {
  final WidgetTester tester;

  SettingsRobot(this.tester);

  Finder get themeToggle => find.byKey(const ValueKey('theme_toggle_switch'));
  Finder get settingsScreen => find.byKey(const ValueKey('settings_screen'));

  Future<void> waitForSettings() async {
    await tester.pumpUntilFound(settingsScreen);
  }

  Future<void> toggleTheme() async {
    await tester.pumpUntilFound(themeToggle);
    await tester.tap(themeToggle);
    // Pump to let the animation and state change finish
    await tester.pump(const Duration(milliseconds: 500));
  }

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
