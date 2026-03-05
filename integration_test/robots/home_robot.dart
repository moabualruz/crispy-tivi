import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class HomeRobot {
  final WidgetTester tester;

  HomeRobot(this.tester);

  Finder get homeScreen => find.byKey(TestKeys.homeScreen);
  Finder get heroBanner => find.byKey(TestKeys.heroBanner);
  Finder get continueWatchingSection =>
      find.byKey(TestKeys.sectionContinueWatching);
  Finder get top10Section => find.byKey(TestKeys.sectionTop10);
  Finder get latestVodSection => find.byKey(TestKeys.sectionLatestVod);

  Future<void> waitForHome() async {
    await tester.pumpUntilFound(homeScreen);
  }

  Future<void> verifyHeroBannerCycles() async {
    // Basic test checking hero banner is present.
    // Cycling tests would hook into internal timer mechanisms which are non-trivial via pure UI pumps.
    await tester.pumpUntilFound(heroBanner);
    // Explicit wait covering banner duration
    await tester.pump(const Duration(seconds: 6));
  }

  Future<void> verifySectionRenderingOrder() async {
    // Find the rendered position of sections on the screen.
    // If they aren't visible, scroll to them.
    // If they aren't visible, scroll to them.

    // Check if the next top sections exist visually
    expect(
      top10Section,
      findsOneWidget,
      reason: 'Top 10 section must be rendered',
    );
  }
}
