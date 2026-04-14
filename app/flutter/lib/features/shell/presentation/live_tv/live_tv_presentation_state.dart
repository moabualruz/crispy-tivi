import 'package:crispy_tivi/features/shell/data/playback_session_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

final class LiveTvPresentationState {
  const LiveTvPresentationState({
    required this.availableGroups,
    required this.group,
    required this.channels,
    required this.focusedChannelIndex,
    required this.playingChannelIndex,
    required this.selectedChannel,
    required this.playingChannel,
    required this.selectedDetail,
    required this.browse,
    required this.guide,
    required this.playerSession,
  });

  factory LiveTvPresentationState.fromRuntime({
    required LiveTvRuntimeSnapshot runtime,
    required LiveTvPanel panel,
    required String groupId,
    required int focusedChannelIndex,
    required int playingChannelIndex,
  }) {
    final LiveTvRuntimeGroupSnapshot group = _selectedGroup(runtime, groupId);
    final List<LiveTvRuntimeChannelSnapshot> runtimeChannels = runtime
        .channelsForGroup(group.id);
    final List<ChannelEntry> channels = runtimeChannels
        .map(_adaptChannelEntry)
        .toList(growable: false);
    if (channels.isEmpty) {
      return LiveTvPresentationState(
        availableGroups: runtime.orderedGroups,
        group: group,
        channels: const <ChannelEntry>[],
        focusedChannelIndex: 0,
        playingChannelIndex: 0,
        selectedChannel: const ChannelEntry(
          number: '',
          name: '',
          program: '',
          timeRange: '',
        ),
        playingChannel: const ChannelEntry(
          number: '',
          name: '',
          program: '',
          timeRange: '',
        ),
        selectedDetail: null,
        browse: LiveTvBrowseContent(
          summaryTitle: runtime.provider.sourceName,
          summaryBody: runtime.provider.summary,
          quickPlayLabel: runtime.selection.primaryAction,
          quickPlayHint:
              'Tune changes only on explicit activation. ${runtime.provider.guideHealth}.',
          selectedChannelNumber: '',
          channelDetails: const <LiveTvChannelDetail>[],
        ),
        guide: _adaptGuideContent(
          runtime.guideForChannelNumbers(const <String>[]),
          panel,
        ),
        playerSession: const PlayerSession(
          kind: PlayerContentKind.live,
          originLabel: 'Live TV · All',
          queueLabel: 'Channels',
          queue: <PlayerQueueItem>[],
          activeIndex: 0,
          primaryActionLabel: 'Watch live',
          secondaryActionLabel: 'Start over',
          playbackUri: null,
          chooserGroups: <PlayerChooserGroup>[],
          statsLines: <String>[],
        ),
      );
    }

    final int clampedFocusedIndex = focusedChannelIndex.clamp(
      0,
      channels.length - 1,
    );
    final int clampedPlayingIndex = playingChannelIndex.clamp(
      0,
      channels.length - 1,
    );
    final ChannelEntry selectedChannel = channels[clampedFocusedIndex];
    final ChannelEntry playingChannel = channels[clampedPlayingIndex];
    final LiveTvChannelDetail? selectedDetail = _adaptRuntimeDetail(
      runtime.channelByNumber(selectedChannel.number),
      runtime.selection.channelNumber == selectedChannel.number
          ? runtime.selection
          : null,
    );
    final LiveTvGuideContent guideContent = _adaptGuideContent(
      runtime.guideForChannelNumbers(
        runtimeChannels.map((LiveTvRuntimeChannelSnapshot channel) {
          return channel.number;
        }),
      ),
      panel,
    );
    final LiveTvBrowseContent browse = _adaptBrowse(runtime, selectedChannel);
    final PlayerSession playerSession = _buildLivePlayerSession(
      runtime: runtime,
      channels: runtimeChannels,
      selectedIndex: clampedFocusedIndex,
      group: group,
      guide: guideContent,
    );

    return LiveTvPresentationState(
      availableGroups: runtime.orderedGroups,
      group: group,
      channels: channels,
      focusedChannelIndex: clampedFocusedIndex,
      playingChannelIndex: clampedPlayingIndex,
      selectedChannel: selectedChannel,
      playingChannel: playingChannel,
      selectedDetail: selectedDetail,
      browse: browse,
      guide: guideContent,
      playerSession: playerSession,
    );
  }

  final List<LiveTvRuntimeGroupSnapshot> availableGroups;
  final LiveTvRuntimeGroupSnapshot group;
  final List<ChannelEntry> channels;
  final int focusedChannelIndex;
  final int playingChannelIndex;
  final ChannelEntry selectedChannel;
  final ChannelEntry playingChannel;
  final LiveTvChannelDetail? selectedDetail;
  final LiveTvBrowseContent browse;
  final LiveTvGuideContent guide;
  final PlayerSession playerSession;

  bool get hasChannels => channels.isNotEmpty;
}

PlayerSession _buildLivePlayerSession({
  required LiveTvRuntimeSnapshot runtime,
  required List<LiveTvRuntimeChannelSnapshot> channels,
  required int selectedIndex,
  required LiveTvRuntimeGroupSnapshot group,
  required LiveTvGuideContent guide,
}) {
  final List<PlayerQueueItem> queue = channels
      .map((LiveTvRuntimeChannelSnapshot channel) {
        final LiveTvChannelDetail? detail = _adaptRuntimeDetail(
          channel,
          runtime.selection.channelNumber == channel.number
              ? runtime.selection
              : null,
        );
        final ChannelEntry entry = _adaptChannelEntry(channel);
        return PlayerQueueItem(
          eyebrow: 'Live TV · ${entry.number}',
          title: detail?.title ?? entry.program,
          subtitle: '${entry.name} · ${entry.timeRange}',
          summary: detail?.summary ?? 'Legacy browse content fallback.',
          progressLabel: detail?.nowLabel ?? 'Now · ${entry.program}',
          progressValue: 0.96,
          badges: detail?.metadataBadges ?? <String>[channel.group],
          detailLines: <String>[
            detail?.nextLabel ?? 'Next · Schedule pending',
            detail?.archiveHint ??
                'EPG and playback metadata stay synchronized.',
            'Channel switching stays inside player.',
          ],
          playbackSource: channel.playbackSource,
          playbackStream: channel.playbackStream,
        );
      })
      .toList(growable: false);
  return PlayerSession(
    kind: PlayerContentKind.live,
    originLabel: 'Live TV · ${group.title}',
    queueLabel: 'Channels',
    queue: queue,
    activeIndex: selectedIndex,
    primaryActionLabel: runtime.selection.primaryAction,
    secondaryActionLabel: runtime.selection.secondaryAction,
    playbackUri: queue[selectedIndex].playbackStream?.uri,
    chooserGroups: chooserGroupsForQueueItem(queue[selectedIndex]),
    statsLines: <String>[
      'Focused guide slot: ${guide.focusedSlot}',
      'Switch path: next/previous channel without exit',
    ],
  );
}

LiveTvRuntimeGroupSnapshot _selectedGroup(
  LiveTvRuntimeSnapshot runtime,
  String groupId,
) {
  for (final LiveTvRuntimeGroupSnapshot group in runtime.orderedGroups) {
    if (group.id == groupId) {
      return group;
    }
  }
  if (runtime.orderedGroups.isNotEmpty) {
    return runtime.orderedGroups.first;
  }
  return const LiveTvRuntimeGroupSnapshot(
    id: 'all',
    title: 'All',
    summary: '',
    channelCount: 0,
    selected: true,
  );
}

ChannelEntry _adaptChannelEntry(LiveTvRuntimeChannelSnapshot channel) {
  return ChannelEntry(
    number: channel.number,
    name: channel.name,
    program: channel.current.title,
    timeRange: channel.current.timeRange,
  );
}

LiveTvBrowseContent _adaptBrowse(
  LiveTvRuntimeSnapshot runtime,
  ChannelEntry selectedChannel,
) {
  return LiveTvBrowseContent(
    summaryTitle: runtime.provider.sourceName,
    summaryBody: runtime.provider.summary,
    quickPlayLabel: runtime.selection.primaryAction,
    quickPlayHint:
        'Tune changes only on explicit activation. ${runtime.provider.guideHealth}.',
    selectedChannelNumber: selectedChannel.number,
    channelDetails: <LiveTvChannelDetail>[
      _adaptRuntimeDetail(
        runtime.channelByNumber(selectedChannel.number),
        runtime.selection.channelNumber == selectedChannel.number
            ? runtime.selection
            : null,
      )!,
    ],
  );
}

LiveTvChannelDetail? _adaptRuntimeDetail(
  LiveTvRuntimeChannelSnapshot channel,
  LiveTvRuntimeSelectionSnapshot? selection,
) {
  return LiveTvChannelDetail(
    number: channel.number,
    brand: channel.name,
    title: channel.current.title,
    summary:
        selection?.channelNumber == channel.number
            ? selection!.now.summary
            : channel.current.summary,
    nowLabel: 'Now · ${channel.current.title}',
    nextLabel: 'Next · ${channel.next.title} at ${channel.next.start}',
    quickPlayLabel:
        selection?.channelNumber == channel.number
            ? selection!.primaryAction
            : 'Watch live',
    metadataBadges:
        selection?.channelNumber == channel.number
            ? selection!.badges
            : <String>[
              channel.group,
              if (channel.liveEdge) 'Live',
              if (channel.catchUp) 'Catch-up',
              if (channel.archive) 'Archive',
            ],
    supportsCatchup: channel.catchUp,
    supportsArchive: channel.archive,
    archiveHint:
        selection?.channelNumber == channel.number &&
                selection!.detailLines.isNotEmpty
            ? selection.detailLines.first
            : 'EPG and playback metadata stay synchronized.',
  );
}

LiveTvGuideContent _adaptGuideContent(
  LiveTvRuntimeGuideSnapshot guide,
  LiveTvPanel panel,
) {
  final String focusedSlot = guide.timeSlots.isNotEmpty ? guide.timeSlots.first : '';
  final String panelLabel = panel == LiveTvPanel.guide ? 'Guide' : 'Browse';
  return LiveTvGuideContent(
    summaryTitle: guide.title,
    summaryBody: '${guide.windowStart} - ${guide.windowEnd} · $panelLabel',
    timeSlots: guide.timeSlots,
    selectedChannelNumber: guide.rows.isNotEmpty ? guide.rows.first.channelNumber : '',
    focusedSlot: focusedSlot,
    rows: guide.rows
        .map(
          (LiveTvRuntimeGuideRowSnapshot row) => LiveTvGuideRowDetail(
            channelNumber: row.channelNumber,
            channelName: row.channelName,
            programs: row.slots
                .map(
                  (LiveTvRuntimeGuideSlotSnapshot slot) => LiveTvProgramDetail(
                    slot: slot.start,
                    title: slot.title,
                    summary: slot.state,
                    durationLabel: slot.displayRange,
                    supportsCatchup: false,
                    supportsArchive: false,
                    liveEdgeLabel: slot.state,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
  );
}
