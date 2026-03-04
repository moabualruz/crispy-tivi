import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class NavigationRobot {
  final WidgetTester tester;

  NavigationRobot(this.tester);

  Finder get appShell => find.byType(MaterialApp); // General assertion target
  Finder get liveTvNavItem => find.byKey(const ValueKey('nav_item_live tv'));
  Finder get vodNavItem => find.byKey(const ValueKey('nav_item_vod'));
  Finder get seriesNavItem => find.byKey(const ValueKey('nav_item_series'));
  Finder get settingsNavItem => find.byKey(const ValueKey('nav_item_settings'));

  Future<void> waitForShell() async {
    await tester.pumpUntilFound(liveTvNavItem);
  }

  Future<void> verifyNavigationItemsExist() async {
    expect(liveTvNavItem, findsOneWidget);
    expect(vodNavItem, findsOneWidget);
    expect(seriesNavItem, findsOneWidget);
    expect(settingsNavItem, findsOneWidget);
  }

  void verifyLiveTvCollapsedConstraint() {
    // Strictly verify the `nav_item_live tv` container is exactly 72dp wide (collapsed).
    final liveTvRect = tester.getRect(liveTvNavItem);
    expect(
      liveTvRect.width,
      72.0,
      reason:
          'Live TV Navigation item must be exactly 72dp wide when collapsed.',
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
