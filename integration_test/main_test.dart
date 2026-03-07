
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import individual test suites
import 'suites/profile_onboarding_test.dart' as profile_test;
import 'suites/navigation_shell_test.dart' as navigation_test;
import 'suites/live_tv_media_test.dart' as live_tv_test;
import 'suites/home_dashboard_test.dart' as home_test;
import 'suites/dvr_cloud_test.dart' as dvr_test;
import 'suites/settings_persistence_test.dart' as settings_test;

import 'test_helpers/ffi_helper.dart';

void main() {
  // Global integration test binding to support flutter driver
  // execution locally and on device.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Suppress connectivity_plus errors on Windows integration tests by mocking the event channel listen method
  final binding = TestDefaultBinaryMessengerBinding.instance;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
    (methodCall) async {
      return null; // Ignore listen/cancel commands for this channel
    },
  );

  // Isolate the test database from the production one.
  // Each target (windows, emulator-5554, etc.) gets its own
  // temp directory so parallel runs on the same host are safe.
  // Also seed a dummy IPTV source so the onboarding wizard
  // is bypassed — tests expect the main app shell.
  setUpAll(() async {
    await FfiTestHelper.ensureTestIsolation();
    await FfiTestHelper.seedTestSource();
  });

  // Master Runner Logic
  // Explicitly run these sequentially to prevent native memory
  // leaks and ensure the FFI state transitions correctly from
  // one test to the next.
  profile_test.main();
  navigation_test.main();
  live_tv_test.main();
  home_test.main();
  dvr_test.main();
  settings_test.main();

  // Clean up the temp test database directory.
  tearDownAll(() => FfiTestHelper.cleanup());
}
