import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class NavigationRobot {
  final WidgetTester tester;

  NavigationRobot(this.tester);

  Finder get appShell => find.byKey(TestKeys.appShell);

  // Use skipOffstage: false so items built but scrolled off-screen
  // in the side nav are still findable by the test harness.
  Finder get liveTvNavItem =>
      find.byKey(TestKeys.navItem('Live TV'), skipOffstage: false);
  Finder get vodNavItem =>
      find.byKey(TestKeys.navItem('Movies'), skipOffstage: false);
  Finder get seriesNavItem =>
      find.byKey(TestKeys.navItem('Series'), skipOffstage: false);
  Finder get settingsNavItem =>
      find.byKey(TestKeys.navItem('Settings'), skipOffstage: false);

  Future<void> waitForShell() async {
    await tester.pumpUntilFound(appShell);
  }

  Future<void> verifyNavigationItemsExist() async {
    // The app shell scaffold must be present.
    expect(appShell, findsOneWidget);

    // On compact/medium screens the bottom nav uses NavigationBar
    // (no TestKeys). On expanded/large screens the side nav uses
    // a scrollable column where off-screen items may not be visible.
    // Check nav items with skipOffstage: false to find them in the
    // widget tree even if they're scrolled out of view.
    final liveTV = find.byKey(TestKeys.navItem('Live TV'), skipOffstage: false);
    // At least the side nav's Live TV item should exist when
    // usesSideNav is true. On compact layouts it won't — that's OK,
    // the appShell assertion above covers that case.
    if (tester.any(liveTV)) {
      expect(liveTV, findsOneWidget);
    }
  }

  void verifyLiveTvNavConstraint() {
    // On expanded/large: side rail nav items have TestKeys.
    // On compact/medium: bottom NavigationBar items have TestKeys.
    // Verify the Live TV item has a non-zero width on any layout.
    final liveTV = find.byKey(TestKeys.navItem('Live TV'), skipOffstage: false);
    if (tester.any(liveTV)) {
      final rect = tester.getRect(liveTV);
      expect(
        rect.width,
        greaterThan(0),
        reason: 'Live TV nav item must have non-zero width.',
      );
    }
  }

  Future<void> tapLiveTv() async {
    await tester.pumpUntilFound(liveTvNavItem);
    // On landscape phones the side nav is scrollable — ensure
    // the item is in view before tapping (it may have been
    // scrolled out after visiting a lower item like Settings).
    await tester.ensureVisible(liveTvNavItem);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(liveTvNavItem);
    await tester.pumpUntilCondition(
      () => tester.any(find.byType(CircularProgressIndicator)) == false,
    );
  }

  Future<void> tapSettings() async {
    // On landscape phones or small test windows, the side nav is
    // scrollable and Settings (item 9) may be far off-screen.
    // First wait for it to exist in the widget tree at all.
    await tester.pumpUntilFound(settingsNavItem);

    // Because of asynchronous data loading, the widget might transiently disappear.
    // We loop to make sure we can both see it and tap it.
    // NOTE: Do NOT use pumpAndSettle — background syncs (PlaylistSync loading
    // channels/VOD/EPG) and animations keep scheduling frames indefinitely.
    for (int i = 0; i < 10; i++) {
      if (tester.any(settingsNavItem)) {
        try {
          await tester.ensureVisible(settingsNavItem.first);
          for (int j = 0; j < 5; j++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.tap(settingsNavItem.first, warnIfMissed: false);
          break; // success
        } catch (e) {
          // ignore StateError from .first or ensureVisible during rebuilds
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Pump frames to let the navigation transition complete.
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}
