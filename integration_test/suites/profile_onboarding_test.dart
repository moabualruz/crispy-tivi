import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../robots/profile_robot.dart';
import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile & Onboarding Suite', () {
    testWidgets('Add Profile -> Create Guest Profile', (
      WidgetTester tester,
    ) async {
      // 1. Initialize FFI specific mock/setup context
      await FfiTestHelper.setupGuestProfileBackendState();

      // 2. Start the App
      app.main();

      // Ensure the initial frame is rendered
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // 3. Interface with Robot
      final profileRobot = ProfileRobot(tester);

      await profileRobot.waitForProfileSelectionScreen();
      await profileRobot.tapAddProfile();
      await profileRobot.tapCreateGuestProfile();

      // 4. Assert Backend State (Simulated here)
      // verify that Rust local SQLite DB has been updated.
      // e.g., expect(await RustLib.api.getProfiles(), isNotEmpty);
      expect(
        profileRobot.guestAvatar,
        findsOneWidget,
        reason: 'Guest profile should be created and visible.',
      );
    });
  });
}
