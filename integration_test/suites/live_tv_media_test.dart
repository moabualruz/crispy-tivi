import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../robots/media_robot.dart';
import '../robots/navigation_robot.dart';
import '../test_helpers/ffi_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FfiTestHelper.ensureTestIsolation();
    await FfiTestHelper.seedTestSource();
  });
  tearDownAll(() => FfiTestHelper.cleanup());

  group('Live TV & Media Engine Suite', () {
    testWidgets(
      'Fetch EPG -> Play Channel',
      // TODO: re-enable once full EPG integration test is wired
      skip: true,
      (WidgetTester tester) async {
        await FfiTestHelper.ensureRustInitialized();

        app.main();
        await tester.pump(const Duration(milliseconds: 500));

        final navRobot = NavigationRobot(tester);
        final mediaRobot = MediaRobot(tester);

        await navRobot.waitForShell();
        await navRobot.tapLiveTv();

        await mediaRobot.waitForEpg();
        await mediaRobot.selectFirstChannel();

        // Wait for player to spin up via pumpUntilFound/Condition mechanics
        // preventing pumpAndSettle timeout
        await mediaRobot.waitForPlayerToStartPlaying();

        // Final assertion: we are in playing state and video exists.
        expect(mediaRobot.videoVideo, findsOneWidget);
      },
    );
  });
}
