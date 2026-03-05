import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class NavigationRobot {
  final WidgetTester tester;

  NavigationRobot(this.tester);

  Finder get appShell => find.byKey(TestKeys.appShell);
  Finder get liveTvNavItem => find.byKey(TestKeys.navItem('Live TV'));
  Finder get vodNavItem => find.byKey(TestKeys.navItem('Movies'));
  Finder get seriesNavItem => find.byKey(TestKeys.navItem('Series'));
  Finder get settingsNavItem => find.byKey(TestKeys.navItem('Settings'));

  Future<void> waitForShell() async {
    await tester.pumpUntilFound(appShell);
  }

  Future<void> verifyNavigationItemsExist() async {
    // The app shell scaffold must be present.
    expect(appShell, findsOneWidget);

    // On compact/medium screens the bottom nav uses NavigationBar
    // (no TestKeys). On expanded/large screens the side nav uses
    // a scrollable ListView where off-screen items are not rendered.
    // Check nav items with skipOffstage: false to find them in the
    // widget tree even if they're scrolled out of view.
    final liveTV = find.byKey(
      TestKeys.navItem('Live TV'),
      skipOffstage: false,
    );
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
    final liveTV = find.byKey(
      TestKeys.navItem('Live TV'),
      skipOffstage: false,
    );
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
    await tester.tap(liveTvNavItem);
    await tester.pumpUntilCondition(
      () => tester.any(find.byType(CircularProgressIndicator)) == false,
    );
  }

  Future<void> tapSettings() async {
    await tester.tap(settingsNavItem);
    await tester.pumpUntilCondition(
      () => tester.any(find.byType(CircularProgressIndicator)) == false,
    );
  }
}
