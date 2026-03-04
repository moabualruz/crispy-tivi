import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class ProfileRobot {
  final WidgetTester tester;

  ProfileRobot(this.tester);

  Finder get addProfileButton => find.text('Add Profile');
  // Or if it's an icon/key, adapt accordingly. E.g., find.byKey(const ValueKey('add_profile_btn'));

  Finder get createGuestButton => find.text('Create Guest Profile');
  Finder get guestAvatar => find.byKey(const ValueKey('guest_avatar'));

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
