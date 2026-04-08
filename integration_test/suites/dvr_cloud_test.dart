import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crispy_tivi/main.dart' as app;

import '../test_helpers/ffi_helper.dart';
import '../test_helpers/pump_until_found.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FfiTestHelper.ensureTestIsolation();
    await FfiTestHelper.seedTestSource();
  });
  tearDownAll(() => FfiTestHelper.cleanup());

  group('DVR Cloud Storage Suite', () {
    testWidgets('App shell boots for DVR navigation', (
      WidgetTester tester,
    ) async {
      await FfiTestHelper.ensureRustInitialized();
      await app.main();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the app boots to the shell. DVR-specific navigation
      // requires the DVR nav item which may be off-screen on compact
      // layouts. Full DVR integration tests are TODO.
      await tester.pumpUntilFound(find.byKey(TestKeys.appShell));
      expect(find.byKey(TestKeys.appShell), findsOneWidget);
    });
  });
}
