import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../test_helpers/pump_until_found.dart';

class MediaRobot {
  final WidgetTester tester;

  MediaRobot(this.tester);

  Finder get epgChannelList => find.byKey(const ValueKey('epg_list'));
  Finder get firstChannelItem => find.byKey(const ValueKey('channel_0'));
  Finder get videoVideo => find.byType(Video); // media_kit video player widget

  Future<void> waitForEpg() async {
    await tester.pumpUntilFound(epgChannelList);
  }

  Future<void> selectFirstChannel() async {
    await tester.pumpUntilFound(firstChannelItem);
    await tester.tap(firstChannelItem);
  }

  Future<void> waitForPlayerToStartPlaying() async {
    // Wait for the Video widget to appear in the tree
    await tester.pumpUntilFound(videoVideo);

    // In a real scenario, we might want to check the internal player state.
    // For this robot, pumping until the video widget is present and no loading
    // spinner is found serves as a proxy for "playing" state in UI integration tests.
    await tester.pumpUntilCondition(
      () => !tester.any(find.byType(CircularProgressIndicator)),
    );
  }
}
