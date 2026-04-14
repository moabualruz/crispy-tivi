import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/live_tv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LiveTvRuntimeSnapshot runtime = LiveTvRuntimeSnapshot(
    title: 'CrispyTivi Live TV Runtime',
    version: '1',
    provider: LiveTvRuntimeProviderSnapshot(
      providerKey: 'home_fiber_iptv',
      providerType: 'M3U + XMLTV',
      family: 'playlist',
      connectionMode: 'remote_url',
      sourceName: 'Home Fiber IPTV',
      status: 'Healthy',
      summary:
          'Live channels and guide data are synchronized for browse and playback.',
      lastSync: '2 minutes ago',
      guideHealth: 'EPG verified',
    ),
    browsing: LiveTvRuntimeBrowsingSnapshot(
      activePanel: 'Channels',
      selectedGroup: 'All',
      selectedChannel: '101 Crispy One',
      groupOrder: <String>['All', 'Sports'],
      groups: <LiveTvRuntimeGroupSnapshot>[
        LiveTvRuntimeGroupSnapshot(
          id: 'all',
          title: 'All',
          summary: 'Every available live channel',
          channelCount: 2,
          selected: true,
        ),
        LiveTvRuntimeGroupSnapshot(
          id: 'sports',
          title: 'Sports',
          summary: 'Live sports and replay-heavy channels',
          channelCount: 1,
          selected: false,
        ),
      ],
    ),
    channels: <LiveTvRuntimeChannelSnapshot>[
      LiveTvRuntimeChannelSnapshot(
        number: '101',
        name: 'Crispy One',
        group: 'News',
        state: 'selected',
        liveEdge: true,
        catchUp: true,
        archive: true,
        current: LiveTvRuntimeProgramSnapshot(
          title: 'Midnight Bulletin',
          summary: 'Late-night national news.',
          start: '21:00',
          end: '22:00',
          progressPercent: 55,
        ),
        next: LiveTvRuntimeProgramSnapshot(
          title: 'Market Close',
          summary: 'Closing bell recap.',
          start: '22:00',
          end: '22:30',
          progressPercent: 0,
        ),
      ),
      LiveTvRuntimeChannelSnapshot(
        number: '118',
        name: 'Arena Live',
        group: 'Sports',
        state: 'playing',
        liveEdge: true,
        catchUp: true,
        archive: true,
        current: LiveTvRuntimeProgramSnapshot(
          title: 'Championship Replay',
          summary: 'Replay block with studio analysis.',
          start: '21:30',
          end: '23:30',
          progressPercent: 33,
        ),
        next: LiveTvRuntimeProgramSnapshot(
          title: 'Locker Room',
          summary: 'Post-game commentary.',
          start: '23:30',
          end: '00:00',
          progressPercent: 0,
        ),
      ),
    ],
    guide: LiveTvRuntimeGuideSnapshot(
      title: 'Live TV Guide',
      windowStart: '21:00',
      windowEnd: '23:00',
      timeSlots: <String>['Now', '21:30', '22:00'],
      rows: <LiveTvRuntimeGuideRowSnapshot>[
        LiveTvRuntimeGuideRowSnapshot(
          channelNumber: '101',
          channelName: 'Crispy One',
          slots: <LiveTvRuntimeGuideSlotSnapshot>[
            LiveTvRuntimeGuideSlotSnapshot(
              start: '21:00',
              end: '22:00',
              title: 'Midnight Bulletin',
              state: 'current',
            ),
            LiveTvRuntimeGuideSlotSnapshot(
              start: '22:00',
              end: '22:30',
              title: 'Market Close',
              state: 'next',
            ),
          ],
        ),
        LiveTvRuntimeGuideRowSnapshot(
          channelNumber: '118',
          channelName: 'Arena Live',
          slots: <LiveTvRuntimeGuideSlotSnapshot>[
            LiveTvRuntimeGuideSlotSnapshot(
              start: '21:30',
              end: '23:30',
              title: 'Championship Replay',
              state: 'current',
            ),
            LiveTvRuntimeGuideSlotSnapshot(
              start: '23:30',
              end: '00:00',
              title: 'Locker Room',
              state: 'next',
            ),
          ],
        ),
      ],
    ),
    selection: LiveTvRuntimeSelectionSnapshot(
      channelNumber: '118',
      channelName: 'Arena Live',
      status: 'Live',
      liveEdge: true,
      catchUp: true,
      archive: true,
      now: LiveTvRuntimeProgramSnapshot(
        title: 'Championship Replay',
        summary:
            'A replay block with postgame analysis and on-screen highlights.',
        start: '21:30',
        end: '23:30',
        progressPercent: 33,
      ),
      next: LiveTvRuntimeProgramSnapshot(
        title: 'Locker Room',
        summary: 'Reaction, interviews, and clipped highlights.',
        start: '23:30',
        end: '00:00',
        progressPercent: 0,
      ),
      primaryAction: 'Watch live',
      secondaryAction: 'Start over',
      badges: <String>['Live', 'Sports', 'Catch-up'],
      detailLines: <String>[
        'Selected detail stays in the right lane while browse remains on the left.',
        'EPG and playback metadata remain synchronized to the same channel selection.',
      ],
    ),
    notes: <String>['Rust-owned runtime snapshot.'],
  );

  Widget buildView({
    required LiveTvPanel panel,
    required String groupId,
    required int focusedChannelIndex,
    required int playingChannelIndex,
    required ValueChanged<String> onSelectGroup,
    required ValueChanged<int> onSelectChannel,
    required VoidCallback onActivateChannel,
    required ValueChanged<PlayerSession> onLaunchPlayer,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LiveTvView(
          runtime: runtime,
          panel: panel,
          groupId: groupId,
          focusedChannelIndex: focusedChannelIndex,
          playingChannelIndex: playingChannelIndex,
          onSelectGroup: onSelectGroup,
          onSelectChannel: onSelectChannel,
          onActivateChannel: onActivateChannel,
          onLaunchPlayer: onLaunchPlayer,
        ),
      ),
    );
  }

  testWidgets('channels view consumes retained runtime for live playback', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool activated = false;
    PlayerSession? launchedSession;

    await tester.pumpWidget(
      buildView(
        panel: LiveTvPanel.channels,
        groupId: 'all',
        focusedChannelIndex: 0,
        playingChannelIndex: 1,
        onSelectGroup: (_) {},
        onSelectChannel: (_) {},
        onActivateChannel: () => activated = true,
        onLaunchPlayer: (PlayerSession session) => launchedSession = session,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home Fiber IPTV'), findsOneWidget);
    expect(
      find.text(
        'Live channels and guide data are synchronized for browse and playback.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('EPG verified'), findsOneWidget);
    expect(find.byKey(const Key('live-tv-tune-action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('live-tv-tune-action')));
    await tester.pumpAndSettle();

    expect(activated, isTrue);
    expect(launchedSession, isNotNull);
    expect(launchedSession!.kind, PlayerContentKind.live);
    expect(launchedSession!.originLabel, 'Live TV · All');
    expect(launchedSession!.queueLabel, 'Channels');
    expect(launchedSession!.primaryActionLabel, 'Watch live');
    expect(launchedSession!.secondaryActionLabel, 'Start over');
    expect(launchedSession!.queue.first.badges, contains('News'));
  });

  testWidgets(
    'guide view consumes retained guide runtime and keeps tune hidden',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildView(
          panel: LiveTvPanel.guide,
          groupId: 'all',
          focusedChannelIndex: 0,
          playingChannelIndex: 1,
          onSelectGroup: (_) {},
          onSelectChannel: (_) {},
          onActivateChannel: () {},
          onLaunchPlayer: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live TV Guide'), findsWidgets);
      expect(find.textContaining('21:00 - 23:00'), findsWidgets);
      expect(
        find.byKey(const Key('live-tv-guide-live-edge-label')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('live-tv-tune-action')), findsNothing);
      expect(find.text('Market Close'), findsWidgets);
    },
  );
}
