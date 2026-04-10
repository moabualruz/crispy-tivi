import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class DvrRobot {
  final WidgetTester tester;

  DvrRobot(this.tester);

  Finder get dvrScreen => find.byKey(TestKeys.dvrScreen);
  Finder get cloudStorageTab => find.byKey(TestKeys.tabCloudStorage);

  // Dedicated S3/WebDAV add buttons are not exposed yet.
  // Finder get configS3Button => find.byKey(TestKeys.configS3Storage);
  // Finder get configWebDavButton => find.byKey(TestKeys.configWebDavStorage);

  Finder get errorSnackbar => find.byType(SnackBar);

  Future<void> waitForDvrScreen() async {
    await tester.pumpUntilFound(dvrScreen);
  }

  Future<void> navigateToCloudStorage() async {
    await tester.tap(cloudStorageTab);
    await tester.pumpAndSettle();
  }

  // Re-enable when dedicated S3/WebDAV add buttons are exposed.
  // Future<void> configureS3Provider() async {
  //   await tester.scrollUntilVisible(
  //     configS3Button,
  //     200,
  //     scrollable: find.byType(SingleChildScrollView),
  //   );
  //   await tester.tap(configS3Button);
  //   await tester.pumpAndSettle();
  // }
}
