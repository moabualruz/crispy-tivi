import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class NavigationRobot {
  final WidgetTester tester;

  NavigationRobot(this.tester);

  Finder get appShell => find.byType(MaterialApp); // General assertion target
  Finder get liveTvNavItem => find.byKey(TestKeys.navItem('Live TV'));
  Finder get vodNavItem => find.byKey(TestKeys.navItem('Movies'));
  Finder get seriesNavItem => find.byKey(TestKeys.navItem('Series'));
  Finder get settingsNavItem => find.byKey(TestKeys.navItem('Settings'));

  Future<void> waitForShell() async {
    await tester.pumpUntilFound(liveTvNavItem);
  }

  Future<void> verifyNavigationItemsExist() async {
    expect(liveTvNavItem, findsOneWidget);
    expect(vodNavItem, findsOneWidget);
    expect(seriesNavItem, findsOneWidget);
    expect(settingsNavItem, findsOneWidget);
  }

  void verifyLiveTvNavConstraint() {
    // Verify the nav item renders with a reasonable width.
    // Collapsed rail = 72dp, expanded rail ≈ 143dp.
    // Both are valid depending on window size.
    final liveTvRect = tester.getRect(liveTvNavItem);
    expect(
      liveTvRect.width,
      greaterThanOrEqualTo(72.0),
      reason: 'Live TV Navigation item must be at least 72dp wide.',
    );
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
