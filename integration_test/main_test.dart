import 'package:integration_test/integration_test.dart';

// Import individual test suites
import 'suites/profile_onboarding_test.dart' as profile_test;
import 'suites/navigation_shell_test.dart' as navigation_test;
import 'suites/live_tv_media_test.dart' as live_tv_test;
import 'suites/settings_persistence_test.dart' as settings_test;
import 'suites/home_dashboard_test.dart' as home_test;
import 'suites/dvr_cloud_test.dart' as dvr_test;

void main() {
  // Global integration test binding to support flutter driver execution locally and on device.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Master Runner Logic
  // Explicitly run these sequentially to prevent native memory leaks
  // and ensure the FFI state transitions correctly from one test to the next.
  profile_test.main();
  navigation_test.main();
  live_tv_test.main();
  settings_test.main();
  home_test.main();
  dvr_test.main();
}
