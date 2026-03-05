import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class ProfileRobot {
  final WidgetTester tester;

  ProfileRobot(this.tester);

  Finder get addProfileButton => find.byKey(TestKeys.addProfileButton);
  Finder get guestAvatar => find.byKey(TestKeys.guestAvatar);

  // No TestKeys constant for "Create Guest Profile" text — keep find.text for now.
  Finder get createGuestButton => find.text('Create Guest Profile');

  Future<void> waitForProfileSelectionScreen() async {
    await tester.pumpUntilFound(addProfileButton);
  }

  Future<void> tapAddProfile() async {
    await tester.tap(addProfileButton);
    // Use smaller intervals to wait for transitions
    await tester.pumpUntilFound(createGuestButton);
  }

  Future<void> tapCreateGuestProfile() async {
    await tester.tap(createGuestButton);
    await tester.pumpUntilFound(guestAvatar);
  }
}
