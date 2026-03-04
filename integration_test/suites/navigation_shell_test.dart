import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../robots/navigation_robot.dart';
import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Global Navigation & Shell Suite', () {
    testWidgets('AppShell Sidebar Verification', (WidgetTester tester) async {
      await FfiTestHelper.setupNavigationBackendState();

      app.main();

      // Ensure the initial routing finishes
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final navRobot = NavigationRobot(tester);

      await navRobot.waitForShell();

      // Atomic checks
      await navRobot.verifyNavigationItemsExist();

      // Constraint Assetion
      navRobot.verifyLiveTvCollapsedConstraint();
    });
  });
}
