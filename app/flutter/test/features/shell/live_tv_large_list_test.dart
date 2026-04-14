import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/live_tv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('live tv channel rail stays lazy with large lists', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final LiveTvRuntimeSnapshot runtime = _largeRuntime(1500);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveTvView(
            runtime: runtime,
            panel: LiveTvPanel.channels,
            groupId: 'all',
            focusedChannelIndex: 0,
            playingChannelIndex: 0,
            onSelectGroup: (_) {},
            onSelectChannel: (_) {},
            onActivateChannel: () {},
            onLaunchPlayer: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live-tv-channel-100')), findsOneWidget);
    expect(find.byKey(const Key('live-tv-channel-1599')), findsNothing);
  });
}

LiveTvRuntimeSnapshot _largeRuntime(int count) {
  final List<LiveTvRuntimeChannelSnapshot> channels =
      List<LiveTvRuntimeChannelSnapshot>.generate(count, (int index) {
        final int channelNumber = 100 + index;
        final String number = '$channelNumber';
        return LiveTvRuntimeChannelSnapshot(
          number: number,
          name: 'Channel $number',
          group: 'All',
          state: 'Now',
          liveEdge: true,
          catchUp: false,
          archive: false,
          playbackSource: PlaybackSourceSnapshot(
            kind: 'live_channel',
            sourceKey: 'stress',
            contentKey: number,
            sourceLabel: 'Live TV',
            handoffLabel: 'Open channel',
          ),
          playbackStream: const PlaybackStreamSnapshot(
            uri: 'https://example.com/live.m3u8',
            transport: 'hls',
            live: true,
            seekable: false,
            resumePositionSeconds: 0,
            sourceOptions: <PlaybackVariantOptionSnapshot>[],
            qualityOptions: <PlaybackVariantOptionSnapshot>[],
            audioOptions: <PlaybackTrackOptionSnapshot>[],
            subtitleOptions: <PlaybackTrackOptionSnapshot>[],
          ),
          current: const LiveTvRuntimeProgramSnapshot(
            title: 'Now',
            summary: 'Current program',
            start: '21:00',
            end: '22:00',
            progressPercent: 25,
          ),
          next: const LiveTvRuntimeProgramSnapshot(
            title: 'Next',
            summary: 'Next program',
            start: '22:00',
            end: '23:00',
            progressPercent: 0,
          ),
        );
      });

  return LiveTvRuntimeSnapshot(
    title: 'Stress Live TV',
    version: '1',
    provider: const LiveTvRuntimeProviderSnapshot(
      providerKey: 'stress',
      providerType: 'M3U + XMLTV',
      family: 'playlist',
      connectionMode: 'remote_url',
      sourceName: 'Stress Source',
      status: 'Healthy',
      summary: 'Stress dataset',
      lastSync: 'Now',
      guideHealth: 'Guide ready',
    ),
    browsing: LiveTvRuntimeBrowsingSnapshot(
      activePanel: 'Channels',
      selectedGroup: 'All',
      selectedChannel: '100 Channel 100',
      groupOrder: const <String>['All'],
      groups: const <LiveTvRuntimeGroupSnapshot>[
        LiveTvRuntimeGroupSnapshot(
          id: 'all',
          title: 'All',
          summary: 'Every channel',
          channelCount: 1500,
          selected: true,
        ),
      ],
    ),
    channels: channels,
    guide: const LiveTvRuntimeGuideSnapshot(
      title: 'Guide',
      windowStart: '21:00',
      windowEnd: '23:00',
      timeSlots: <String>['21:00', '22:00'],
      rows: <LiveTvRuntimeGuideRowSnapshot>[],
    ),
    selection: const LiveTvRuntimeSelectionSnapshot(
      channelNumber: '100',
      channelName: 'Channel 100',
      status: 'Playing',
      liveEdge: true,
      catchUp: false,
      archive: false,
      now: LiveTvRuntimeProgramSnapshot(
        title: 'Now',
        summary: 'Current program',
        start: '21:00',
        end: '22:00',
        progressPercent: 25,
      ),
      next: LiveTvRuntimeProgramSnapshot(
        title: 'Next',
        summary: 'Next program',
        start: '22:00',
        end: '23:00',
        progressPercent: 0,
      ),
      primaryAction: 'Watch live',
      secondaryAction: 'Start over',
      badges: <String>['Live'],
      detailLines: <String>['Stress runtime'],
    ),
    notes: const <String>['Stress dataset.'],
  );
}
