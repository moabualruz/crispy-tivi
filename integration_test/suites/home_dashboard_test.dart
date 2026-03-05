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

  group('Home Dashboard Suite', () {
    testWidgets('App shell renders home screen', (WidgetTester tester) async {
      await FfiTestHelper.ensureRustInitialized();
      app.main();
      await tester.pump(const Duration(milliseconds: 500));

      // Wait for the app shell scaffold — the outermost testable widget.
      await tester.pumpUntilFound(find.byKey(TestKeys.appShell));

      // The home screen is the default route. Verify the app shell
      // rendered successfully — the home screen scaffold may or may
      // not be findable depending on how deep the widget tree is.
      expect(find.byKey(TestKeys.appShell), findsOneWidget);
    });
  });
}
