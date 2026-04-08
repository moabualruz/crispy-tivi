import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../robots/navigation_robot.dart';
import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FfiTestHelper.ensureTestIsolation();
    await FfiTestHelper.seedTestSource();
  });
  tearDownAll(() => FfiTestHelper.cleanup());

  group('Profile & Onboarding Suite', () {
    testWidgets('App boots to shell when source exists', (
      WidgetTester tester,
    ) async {
      await FfiTestHelper.setupGuestProfileBackendState();

      await app.main();
      await tester.pump(const Duration(milliseconds: 500));

      // With a seeded source the onboarding wizard is bypassed
      // and the app should land on the main shell.
      final navRobot = NavigationRobot(tester);
      await navRobot.waitForShell();
      await navRobot.verifyNavigationItemsExist();
    });
  });
}
