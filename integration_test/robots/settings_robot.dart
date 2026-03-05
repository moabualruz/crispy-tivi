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

  /// Scrolls the settings content area until [finder] becomes
  /// visible. Uses [dragUntilVisible] which works regardless of
  /// how many Scrollable widgets exist on-screen (side nav, tabs,
  /// settings content).
  Future<void> _scrollIntoView(Finder finder) async {
    await tester.dragUntilVisible(
      finder,
      settingsScreen,
      const Offset(0, -200),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Returns the current value of a [SwitchListTile].
  ///
  /// Scrolls the tile into view first because the settings list is
  /// lazy and may not build off-screen items on short viewports
  /// (e.g. landscape phones at 411dp height).
  Future<bool> getSwitchValue(String title) async {
    final finder = switchTile(title);
    await _scrollIntoView(finder);
    return tester.widget<SwitchListTile>(finder).value;
  }

  /// Taps a [SwitchListTile] to toggle it.
  ///
  /// Scrolls the tile into view first. An extra pump after
  /// scrolling lets the scroll animation settle so the tap offset
  /// is accurate.
  Future<void> toggleSwitch(String title) async {
    final finder = switchTile(title);
    await _scrollIntoView(finder);
    await tester.tap(finder);
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
