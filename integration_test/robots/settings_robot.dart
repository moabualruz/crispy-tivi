import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class SettingsRobot {
  final WidgetTester tester;

  SettingsRobot(this.tester);

  Finder get settingsScreen => find.byKey(TestKeys.settingsScreen);

  Future<void> waitForSettings() async {
    await tester.pumpUntilFound(settingsScreen);
  }

  /// Finds a [SwitchListTile] by its title text.
  Finder switchTile(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(SwitchListTile),
  );

  /// Returns the current value of a [SwitchListTile].
  bool getSwitchValue(String title) {
    final widget = tester.widget<SwitchListTile>(switchTile(title));
    return widget.value;
  }

  /// Taps a [SwitchListTile] to toggle it.
  Future<void> toggleSwitch(String title) async {
    await tester.ensureVisible(switchTile(title));
    await tester.tap(switchTile(title));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Taps a settings category tab by label.
  Future<void> tapTab(String label) async {
    final tab = find.text(label);
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 500));
  }
}
