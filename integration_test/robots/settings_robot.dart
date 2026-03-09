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
    await tester.pumpUntilFound(find.byType(TabBarView));
    // Wait until the General tab's actual content is rendered (not the
    // shimmer placeholder).  On slower devices, settingsAsync may take
    // a while to resolve.
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (_hasTabContent('General')) break;
    }
  }

  /// Finds a [SwitchListTile] by its title text.
  Finder switchTile(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(SwitchListTile),
  );

  Future<void> _scrollIntoView(Finder finder) async {
    // Settings tabs use ListView (not ListView.builder), so all items
    // exist in the widget tree even when off-screen.  We just need to
    // wait for the tab content to render, then ensureVisible scrolls
    // the item on-screen.  This avoids dragUntilVisible which has
    // race conditions on slower devices (Android emulators).
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(finder)) {
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 500));
        return;
      }
    }

    throw StateError(
      'Widget "${finder.describeMatch(Plurality.many)}" not found in settings screen '
      'after 8 seconds of pumping',
    );
  }

  /// Returns the current value of a [SwitchListTile].
  Future<bool> getSwitchValue(String title) async {
    final finder = switchTile(title);
    await _scrollIntoView(finder);

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final tile = tester.widget<SwitchListTile>(finder);
    return tile.value;
  }

  /// Taps a [SwitchListTile] to toggle it.
  Future<void> toggleSwitch(String title) async {
    final finder = switchTile(title);
    await _scrollIntoView(finder);

    final switchWidgetFinder = find.descendant(
      of: finder,
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(switchWidgetFinder.first);
    await tester.tap(switchWidgetFinder.first);

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Switches to a settings category tab by label.
  Future<void> tapTab(String label) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      await tester.pumpUntilFound(find.byType(TabBar));

      final stabilizeFrames = 20 + attempt * 15;
      for (int i = 0; i < stabilizeFrames; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      if (!tester.any(find.byType(TabBar))) continue;

      final tabBar = tester.widget<TabBar>(find.byType(TabBar).first);
      int targetIndex = -1;
      for (int i = 0; i < tabBar.tabs.length; i++) {
        final tab = tabBar.tabs[i] as Tab;
        if (tab.text == label) {
          targetIndex = i;
          break;
        }
      }
      if (targetIndex == -1) {
        throw StateError('Tab "$label" not found in TabBar');
      }

      final ctrl = tabBar.controller;
      if (ctrl == null) continue;

      // If already at target, verify content is visible.
      if (ctrl.index == targetIndex) {
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (_hasTabContent(label)) return;

        // Force-sync: jump away and back.
        final temp = targetIndex == 0 ? 1 : 0;
        ctrl.animateTo(temp);
        for (int i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        ctrl.animateTo(targetIndex);
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (_hasTabContent(label)) return;
        continue;
      }

      ctrl.animateTo(targetIndex);
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final ctrlAfter =
          tester.widget<TabBar>(find.byType(TabBar).first).controller;
      final hasContent = _hasTabContent(label);

      if (ctrlAfter?.index == targetIndex && hasContent) return;

      // Force-sync if controller is right but content wrong.
      if (ctrlAfter?.index == targetIndex && !hasContent) {
        final temp = targetIndex == 0 ? 1 : 0;
        ctrlAfter!.animateTo(temp);
        for (int i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        ctrlAfter.animateTo(targetIndex);
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (_hasTabContent(label)) return;
      }
    }

    throw StateError('Failed to switch to "$label" tab after 3 attempts');
  }

  bool _hasTabContent(String label) {
    switch (label) {
      case 'General':
        return tester.any(find.text('Auto-resume last channel')) ||
            tester.any(find.text('Theme Base'));
      case 'Playback':
        return tester.any(find.text('Auto Frame Rate')) ||
            tester.any(find.text('Hardware Decoding'));
      case 'Sources':
        return tester.any(find.text('Add Source'));
      case 'Data':
        return tester.any(find.text('Sync'));
      case 'Advanced':
        return tester.any(find.text('DVR'));
      case 'About':
        return tester.any(find.text('Version'));
      default:
        return true;
    }
  }
}
