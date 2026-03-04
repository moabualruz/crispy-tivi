import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_until_found.dart';

class DvrRobot {
  final WidgetTester tester;

  DvrRobot(this.tester);

  Finder get dvrScreen => find.byKey(const ValueKey('dvr_screen'));
  Finder get cloudStorageTab => find.byKey(const ValueKey('tab_cloud_storage'));
  Finder get configS3Button => find.byKey(const ValueKey('config_s3_storage'));
  Finder get configWebDavButton =>
      find.byKey(const ValueKey('config_webdav_storage'));
  Finder get errorSnackbar => find.byType(SnackBar);

  Future<void> waitForDvrScreen() async {
    await tester.pumpUntilFound(dvrScreen);
  }

  Future<void> navigateToCloudStorage() async {
    await tester.tap(cloudStorageTab);
    await tester.pumpAndSettle();
  }

  Future<void> configureS3Provider() async {
    await tester.scrollUntilVisible(
      configS3Button,
      200,
      scrollable: find.byType(SingleChildScrollView),
    );
    await tester.tap(configS3Button);
    await tester.pumpAndSettle();
  }
}
