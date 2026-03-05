import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../robots/home_robot.dart';
import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FfiTestHelper.ensureTestIsolation();
    await FfiTestHelper.seedTestSource();
  });
  tearDownAll(() => FfiTestHelper.cleanup());

  group('Home Dashboard Suite', () {
    testWidgets('Verify Hero cycle and section order', (
      WidgetTester tester,
    ) async {
      await FfiTestHelper.ensureRustInitialized();
      app.main();
      await tester.pump(const Duration(milliseconds: 500));

      final homeRobot = HomeRobot(tester);

      await homeRobot.waitForHome();

      // Feature: Home 4.14 testing hero cycle rendering
      await homeRobot.verifyHeroBannerCycles();

      // Feature: Home 4.14 testing layout order mappings
      await homeRobot.verifySectionRenderingOrder();
    });
  });
}
