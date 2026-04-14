import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/live_tv/live_tv_presentation_adapter.dart';
import 'package:crispy_tivi/features/shell/presentation/live_tv/live_tv_presentation_state.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:flutter/material.dart';

class LiveTvView extends StatelessWidget {
  const LiveTvView({
    required this.runtime,
    required this.panel,
    required this.groupId,
    required this.focusedChannelIndex,
    required this.playingChannelIndex,
    required this.onSelectGroup,
    required this.onSelectChannel,
    required this.onActivateChannel,
    required this.onLaunchPlayer,
    super.key,
  });

  final LiveTvRuntimeSnapshot runtime;
  final LiveTvPanel panel;
  final String groupId;
  final int focusedChannelIndex;
  final int playingChannelIndex;
  final ValueChanged<String> onSelectGroup;
  final ValueChanged<int> onSelectChannel;
  final VoidCallback onActivateChannel;
  final ValueChanged<PlayerSession> onLaunchPlayer;

  @override
  Widget build(BuildContext context) {
    final LiveTvPresentationState state = LiveTvPresentationAdapter.build(
      runtime: runtime,
      panel: panel,
      groupId: groupId,
      focusedChannelIndex: focusedChannelIndex,
      playingChannelIndex: playingChannelIndex,
    );
    if (panel == LiveTvPanel.guide) {
      return _GuideView(state: state, onSelectGroup: onSelectGroup);
    }
    return _ChannelsView(
      state: state,
      onSelectGroup: onSelectGroup,
      onSelectChannel: onSelectChannel,
      onActivateChannel: onActivateChannel,
      onLaunchPlayer: onLaunchPlayer,
    );
  }
}

class _ChannelsView extends StatelessWidget {
  const _ChannelsView({
    required this.state,
    required this.onSelectGroup,
    required this.onSelectChannel,
    required this.onActivateChannel,
    required this.onLaunchPlayer,
  });

  final LiveTvPresentationState state;
  final ValueChanged<String> onSelectGroup;
  final ValueChanged<int> onSelectChannel;
  final VoidCallback onActivateChannel;
  final ValueChanged<PlayerSession> onLaunchPlayer;

  @override
  Widget build(BuildContext context) {
    if (!state.hasChannels) {
      return const _EmptyLiveTvState(
        title: 'No Live TV sources yet',
        summary:
            'Configure and import a provider before channels and guide data can appear here.',
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 5,
          child: DecoratedBox(
            decoration: CrispyShellRoles.panelDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionHeader(
                    title: 'Channels',
                    subtitle:
                        'Channel browse stays on the left. Explicit tune happens only in the selected detail lane.',
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.large),
                  _ChannelListHeader(
                    totalCount: state.channels.length,
                    groupLabel: state.group.title,
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.channels.length,
                      separatorBuilder:
                          (BuildContext context, int index) => const SizedBox(
                            height: CrispyOverhaulTokens.small,
                          ),
                      itemBuilder:
                          (BuildContext context, int index) => _ChannelRow(
                            entry: state.channels[index],
                            selected: index == state.playerSession.activeIndex,
                            playing: index == state.playingChannelIndex,
                            itemKey: Key(
                              'live-tv-channel-${state.channels[index].number}',
                            ),
                            onTap: () => onSelectChannel(index),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: CrispyOverhaulTokens.large),
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: CrispyShellRoles.insetPanelDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
                  child: _GroupRail(
                    title: 'Browse groups',
                    values: state.availableGroups,
                    selected: state.group,
                    labelBuilder:
                        (LiveTvRuntimeGroupSnapshot value) => value.title,
                    keyBuilder:
                        (LiveTvRuntimeGroupSnapshot value) =>
                            'live-tv-group-${value.id}',
                    onSelect:
                        (LiveTvRuntimeGroupSnapshot value) =>
                            onSelectGroup(value.id),
                    axis: Axis.horizontal,
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.large),
              Expanded(
                child: DecoratedBox(
                  decoration: CrispyShellRoles.panelDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
                    child: _ChannelDetailPane(
                      browse: state.browse,
                      selectedChannel: state.selectedChannel,
                      selectedDetail: state.selectedDetail,
                      groupLabel: state.group.title,
                      playingChannel: state.playingChannel,
                      guide: state.guide,
                      onActivateChannel: () {
                        onActivateChannel();
                        onLaunchPlayer(state.playerSession);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.large),
              SizedBox(
                height: 214,
                child: _GuideSnapshotPanel(
                  guide: state.guide,
                  selectedChannelNumber: state.selectedChannel.number,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideView extends StatelessWidget {
  const _GuideView({required this.state, required this.onSelectGroup});

  final LiveTvPresentationState state;
  final ValueChanged<String> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    if (!state.hasChannels) {
      return const _EmptyLiveTvState(
        title: 'Guide unavailable',
        summary:
            'Guide view appears after a source imports channels and EPG data.',
      );
    }
    final ChannelEntry selectedChannel = state.selectedChannel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 304,
          child: DecoratedBox(
            decoration: CrispyShellRoles.panelDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SectionHeader(
                      title: 'Guide groups',
                      subtitle:
                          'Guide focus updates structured detail overlays and never retunes on browse.',
                    ),
                    const SizedBox(height: CrispyOverhaulTokens.medium),
                    _GroupRail(
                      title: 'Browse groups',
                      values: state.availableGroups,
                      selected: state.group,
                      labelBuilder:
                          (LiveTvRuntimeGroupSnapshot value) => value.title,
                      keyBuilder:
                          (LiveTvRuntimeGroupSnapshot value) =>
                              'live-tv-group-${value.id}',
                      onSelect:
                          (LiveTvRuntimeGroupSnapshot value) =>
                              onSelectGroup(value.id),
                    ),
                    const SizedBox(height: CrispyOverhaulTokens.large),
                    _InfoBadge(
                      label: 'Selected channel',
                      value:
                          '${selectedChannel.number} ${selectedChannel.name}',
                    ),
                    const SizedBox(height: CrispyOverhaulTokens.small),
                    _InfoBadge(
                      label: 'Focused slot',
                      value: state.guide.focusedSlot,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: CrispyOverhaulTokens.large),
        Expanded(
          child: Column(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: DecoratedBox(
                  decoration: CrispyShellRoles.panelDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
                    child: _GuidePreviewPane(
                      selectedChannel: selectedChannel,
                      guide: state.guide,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.large),
              Expanded(
                flex: 7,
                child: DecoratedBox(
                  decoration: CrispyShellRoles.insetPanelDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
                    child: _GuideMatrix(
                      guide: state.guide,
                      selectedChannelNumber: selectedChannel.number,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyLiveTvState extends StatelessWidget {
  const _EmptyLiveTvState({required this.title, required this.summary});

  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: textTheme.titleLarge),
        const SizedBox(height: CrispyOverhaulTokens.compact),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GroupRail<T> extends StatelessWidget {
  const _GroupRail({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.keyBuilder,
    required this.onSelect,
    this.axis = Axis.vertical,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final String Function(T value) keyBuilder;
  final ValueChanged<T> onSelect;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool horizontal = axis == Axis.horizontal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        if (horizontal)
          DecoratedBox(
            decoration: CrispyShellRoles.navGroupDecoration(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(CrispyShellRoles.navGroupInset),
                child: Row(
                  children: values
                      .map(
                        (T value) => Padding(
                          padding: const EdgeInsets.only(
                            right: CrispyShellRoles.navGroupInset,
                          ),
                          child: _GroupRailItem<T>(
                            itemKey: Key(keyBuilder(value)),
                            label: labelBuilder(value),
                            selected: value == selected,
                            onPressed: () => onSelect(value),
                            compact: true,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          )
        else
          ...values.map(
            (T value) => Padding(
              padding: const EdgeInsets.only(
                bottom: CrispyOverhaulTokens.small,
              ),
              child: _GroupRailItem<T>(
                itemKey: Key(keyBuilder(value)),
                label: labelBuilder(value),
                selected: value == selected,
                onPressed: () => onSelect(value),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupRailItem<T> extends StatelessWidget {
  const _GroupRailItem({
    required this.itemKey,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final Key itemKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ShellControlButton(
      controlKey: itemKey,
      label: label,
      onPressed: onPressed,
      controlRole: ShellControlRole.selector,
      presentation: ShellControlPresentation.textOnly,
      selected: selected,
      contentAlignment:
          compact ? Alignment.center : AlignmentDirectional.centerStart,
      expandLabelRow: !compact,
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    super.key,
    required this.label,
    required this.value,
    this.maxValueLines = 2,
  });

  final String label;
  final String value;
  final int maxValueLines;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.small,
          vertical: CrispyOverhaulTokens.compact,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              value,
              maxLines: maxValueLines,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelListHeader extends StatelessWidget {
  const _ChannelListHeader({
    required this.totalCount,
    required this.groupLabel,
  });

  final int totalCount;
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _InfoBadge(label: 'Active group', value: groupLabel)),
        const SizedBox(width: CrispyOverhaulTokens.small),
        Expanded(
          child: _InfoBadge(label: 'Showing', value: '$totalCount channels'),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.entry,
    required this.selected,
    required this.playing,
    required this.itemKey,
    required this.onTap,
  });

  final ChannelEntry entry;
  final bool selected;
  final bool playing;
  final Key itemKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: itemKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
        child: DecoratedBox(
          decoration:
              selected
                  ? CrispyShellRoles.insetPanelDecoration()
                  : CrispyShellRoles.denseCardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 84,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.number,
                        style: textTheme.titleMedium?.copyWith(
                          color: CrispyOverhaulTokens.accentFocus,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.compact),
                      Text(
                        selected ? 'Selected' : 'Browse',
                        style: textTheme.labelSmall?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              entry.name,
                              style: textTheme.titleMedium,
                            ),
                          ),
                          if (playing)
                            Text(
                              'Playing',
                              style: textTheme.labelSmall?.copyWith(
                                color: CrispyOverhaulTokens.accentFocus,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.compact),
                      Text(
                        entry.program,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      selected ? 'Now' : 'Later',
                      style: textTheme.bodySmall?.copyWith(
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CrispyOverhaulTokens.compact),
                    Text(entry.timeRange, style: textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelDetailPane extends StatelessWidget {
  const _ChannelDetailPane({
    required this.browse,
    required this.selectedChannel,
    required this.selectedDetail,
    required this.groupLabel,
    required this.playingChannel,
    required this.guide,
    required this.onActivateChannel,
  });

  final LiveTvBrowseContent browse;
  final ChannelEntry selectedChannel;
  final LiveTvChannelDetail? selectedDetail;
  final String groupLabel;
  final ChannelEntry playingChannel;
  final LiveTvGuideContent guide;
  final VoidCallback onActivateChannel;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String primaryProgram =
        selectedDetail?.title ?? selectedChannel.program;
    final String summary =
        selectedDetail?.summary ??
        'Selected channel detail stays explicit before playback.';
    final String nowLabel =
        selectedDetail?.nowLabel ?? 'Now · ${selectedChannel.program}';
    final String nextLabel =
        selectedDetail?.nextLabel ?? 'Next · Schedule pending';
    final String quickPlayLabel =
        selectedDetail?.quickPlayLabel ?? 'Play selected channel';
    final String archiveHint = selectedDetail?.archiveHint ?? 'Preview only';
    final String brandLabel = selectedDetail?.brand ?? selectedChannel.name;
    final List<String> metadataBadges =
        selectedDetail?.metadataBadges ?? <String>[groupLabel];
    final bool selectedIsPlaying =
        selectedChannel.number == playingChannel.number;
    final String playingNowLabel = 'Playing ${playingChannel.number}';
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double badgeGap = CrispyOverhaulTokens.small;
        final double paneWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 720;
        final double topBadgeWidth = ((paneWidth - (badgeGap * 2)) / 3).clamp(
          136,
          220,
        );
        final double slotWidth = ((paneWidth - (badgeGap * 3)) / 4).clamp(
          104,
          156,
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: paneWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(
                  spacing: badgeGap,
                  runSpacing: badgeGap,
                  children: <Widget>[
                    SizedBox(
                      width: topBadgeWidth,
                      child: _InfoBadge(
                        label: selectedIsPlaying ? 'Playing now' : 'Playback',
                        value:
                            selectedIsPlaying ? 'Active tune' : 'Preview only',
                        maxValueLines: 1,
                      ),
                    ),
                    SizedBox(
                      width: topBadgeWidth,
                      child: _InfoBadge(
                        label: 'Group',
                        value: groupLabel,
                        maxValueLines: 1,
                      ),
                    ),
                    SizedBox(
                      width: topBadgeWidth,
                      child: _InfoBadge(
                        key: const Key('live-tv-playing-channel-label'),
                        label: 'Now playing',
                        value: playingNowLabel,
                        maxValueLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CrispyOverhaulTokens.large),
                DecoratedBox(
                  decoration: CrispyShellRoles.previewStageDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          browse.summaryTitle,
                          style: textTheme.titleLarge?.copyWith(
                            color: CrispyOverhaulTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.compact),
                        Text(
                          browse.summaryBody,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.small),
                        Text(
                          brandLabel,
                          style: textTheme.bodyLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.medium),
                        Wrap(
                          spacing: CrispyOverhaulTokens.small,
                          runSpacing: CrispyOverhaulTokens.small,
                          children: <Widget>[
                            _LiveTvActionSurface(
                              key: const Key('live-tv-tune-action'),
                              label: quickPlayLabel,
                              emphasis: true,
                              onTap: onActivateChannel,
                            ),
                            const _LiveTvActionSurface(label: 'Open guide'),
                            const _LiveTvActionSurface(label: 'More info'),
                          ],
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.small),
                        Text(
                          browse.quickPlayHint,
                          style: textTheme.bodySmall?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.medium),
                        DecoratedBox(
                          decoration:
                              CrispyShellRoles.heroArtworkScrimDecoration(),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              CrispyOverhaulTokens.medium,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  primaryProgram,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    color: CrispyOverhaulTokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(
                                  height: CrispyOverhaulTokens.compact,
                                ),
                                Text(
                                  nowLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: CrispyOverhaulTokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(
                                  height: CrispyOverhaulTokens.compact,
                                ),
                                Text(
                                  summary,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: CrispyOverhaulTokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(
                                  height: CrispyOverhaulTokens.compact,
                                ),
                                Text(
                                  archiveHint,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: CrispyOverhaulTokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(
                                  height: CrispyOverhaulTokens.medium,
                                ),
                                Wrap(
                                  spacing: CrispyOverhaulTokens.small,
                                  runSpacing: CrispyOverhaulTokens.small,
                                  children: metadataBadges
                                      .map(
                                        (String badge) => _InfoBadge(
                                          label: 'Tag',
                                          value: badge,
                                          maxValueLines: 1,
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                                const SizedBox(
                                  height: CrispyOverhaulTokens.medium,
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: _InfoBadge(
                                        label: 'On now',
                                        value: nowLabel,
                                        maxValueLines: 2,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: CrispyOverhaulTokens.small,
                                    ),
                                    Expanded(
                                      child: _InfoBadge(
                                        label: 'Up next',
                                        value: nextLabel,
                                        maxValueLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: CrispyOverhaulTokens.small,
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: _InfoBadge(
                                        label: 'Catch-up',
                                        value:
                                            selectedDetail?.supportsCatchup ??
                                                    false
                                                ? 'Available'
                                                : 'Unavailable',
                                        maxValueLines: 1,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: CrispyOverhaulTokens.small,
                                    ),
                                    Expanded(
                                      child: _InfoBadge(
                                        label: 'Archive',
                                        value:
                                            selectedDetail?.supportsArchive ??
                                                    false
                                                ? 'Available'
                                                : 'Unavailable',
                                        maxValueLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CrispyOverhaulTokens.medium),
                Wrap(
                  spacing: CrispyOverhaulTokens.small,
                  runSpacing: CrispyOverhaulTokens.small,
                  children: guide.timeSlots
                      .skip(1)
                      .map(
                        (String slot) => SizedBox(
                          width: slotWidth,
                          child: _InfoBadge(
                            label: 'Slot',
                            value: slot,
                            maxValueLines: 1,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GuideSnapshotPanel extends StatelessWidget {
  const _GuideSnapshotPanel({
    required this.guide,
    required this.selectedChannelNumber,
  });

  final LiveTvGuideContent guide;
  final String selectedChannelNumber;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Scrollbar(
          child: SingleChildScrollView(
            primary: false,
            child: _GuideMatrix(
              guide: guide,
              selectedChannelNumber: selectedChannelNumber,
              compact: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveTvActionSurface extends StatelessWidget {
  const _LiveTvActionSurface({
    super.key,
    required this.label,
    this.emphasis = false,
    this.onTap,
  });

  final String label;
  final bool emphasis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
        child: DecoratedBox(
          decoration:
              emphasis
                  ? CrispyShellRoles.insetPanelDecoration()
                  : CrispyShellRoles.infoPlateDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispyOverhaulTokens.medium,
              vertical: CrispyOverhaulTokens.small,
            ),
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color:
                    emphasis
                        ? CrispyOverhaulTokens.textPrimary
                        : CrispyOverhaulTokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidePreviewPane extends StatelessWidget {
  const _GuidePreviewPane({required this.selectedChannel, required this.guide});

  final ChannelEntry selectedChannel;
  final LiveTvGuideContent guide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxHeight < 240) {
          return _CompactGuidePreviewPane(
            selectedChannel: selectedChannel,
            guide: guide,
          );
        }
        return _ExpandedGuidePreviewPane(
          selectedChannel: selectedChannel,
          guide: guide,
        );
      },
    );
  }
}

class _ExpandedGuidePreviewPane extends StatelessWidget {
  const _ExpandedGuidePreviewPane({
    required this.selectedChannel,
    required this.guide,
  });

  final ChannelEntry selectedChannel;
  final LiveTvGuideContent guide;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final LiveTvGuideRowDetail? row = _guideRowForChannel(
      guide.rows,
      selectedChannel.number,
    );
    final LiveTvProgramDetail? focusedProgram = _programForSlot(
      row,
      guide.focusedSlot,
    );
    return DecoratedBox(
      decoration: CrispyShellRoles.previewStageDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _InfoBadge(
                  label: 'Guide time',
                  value: guide.focusedSlot,
                  maxValueLines: 1,
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                _InfoBadge(
                  label: 'Channel',
                  value: selectedChannel.number,
                  maxValueLines: 1,
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                _InfoBadge(
                  key: const Key('live-tv-guide-live-edge-label'),
                  label: 'State',
                  value: focusedProgram?.liveEdgeLabel ?? 'Guide browse',
                  maxValueLines: 1,
                ),
                const Spacer(),
                Text(
                  guide.summaryBody,
                  style: textTheme.bodySmall?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            Expanded(
              child: DecoratedBox(
                decoration: CrispyShellRoles.heroArtworkScrimDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        guide.summaryTitle,
                        style: textTheme.titleLarge?.copyWith(
                          color: CrispyOverhaulTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.compact),
                      Text(
                        focusedProgram?.title ?? selectedChannel.program,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      Text(
                        focusedProgram?.summary ?? guide.summaryBody,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      Wrap(
                        spacing: CrispyOverhaulTokens.small,
                        runSpacing: CrispyOverhaulTokens.small,
                        children: <Widget>[
                          _InfoBadge(
                            label: 'Duration',
                            value: focusedProgram?.durationLabel ?? 'Unknown',
                          ),
                          _InfoBadge(
                            label: 'Catch-up',
                            value:
                                (focusedProgram?.supportsCatchup ?? false)
                                    ? 'Available'
                                    : 'Unavailable',
                          ),
                          _InfoBadge(
                            label: 'Archive',
                            value:
                                (focusedProgram?.supportsArchive ?? false)
                                    ? 'Available'
                                    : 'Unavailable',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactGuidePreviewPane extends StatelessWidget {
  const _CompactGuidePreviewPane({
    required this.selectedChannel,
    required this.guide,
  });

  final ChannelEntry selectedChannel;
  final LiveTvGuideContent guide;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final LiveTvGuideRowDetail? row = _guideRowForChannel(
      guide.rows,
      selectedChannel.number,
    );
    final LiveTvProgramDetail? focusedProgram = _programForSlot(
      row,
      guide.focusedSlot,
    );
    return DecoratedBox(
      decoration: CrispyShellRoles.previewStageDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double badgeWidth =
                ((constraints.maxWidth - (CrispyOverhaulTokens.small * 2)) / 3)
                    .clamp(96, 180);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  guide.summaryTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: CrispyOverhaulTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: CrispyOverhaulTokens.small),
                Wrap(
                  spacing: CrispyOverhaulTokens.small,
                  runSpacing: CrispyOverhaulTokens.small,
                  children: <Widget>[
                    SizedBox(
                      width: badgeWidth,
                      child: _InfoBadge(
                        label: 'Guide time',
                        value: guide.focusedSlot,
                        maxValueLines: 1,
                      ),
                    ),
                    SizedBox(
                      width: badgeWidth,
                      child: _InfoBadge(
                        label: 'Channel',
                        value: selectedChannel.number,
                        maxValueLines: 1,
                      ),
                    ),
                    SizedBox(
                      width: badgeWidth,
                      child: _InfoBadge(
                        key: const Key('live-tv-guide-live-edge-label'),
                        label: 'State',
                        value: focusedProgram?.liveEdgeLabel ?? 'Guide browse',
                        maxValueLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CrispyOverhaulTokens.small),
                Text(
                  focusedProgram?.title ?? selectedChannel.program,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: CrispyOverhaulTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: CrispyOverhaulTokens.compact),
                Text(
                  focusedProgram?.liveEdgeLabel ??
                      'Guide focus never starts playback',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GuideMatrix extends StatelessWidget {
  const _GuideMatrix({
    required this.guide,
    required this.selectedChannelNumber,
    this.compact = false,
  });

  final LiveTvGuideContent guide;
  final String selectedChannelNumber;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (guide.rows.isEmpty || guide.timeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<LiveTvGuideRowDetail> visibleRows = guide.rows;
    final double channelColumnWidth = compact ? 124 : 160;
    final EdgeInsets cellPadding =
        compact
            ? const EdgeInsets.symmetric(
              horizontal: CrispyOverhaulTokens.small,
              vertical: CrispyOverhaulTokens.compact,
            )
            : const EdgeInsets.all(CrispyOverhaulTokens.small);
    final TextStyle? cellStyle =
        compact
            ? textTheme.bodySmall?.copyWith(
              color: CrispyOverhaulTokens.textSecondary,
            )
            : textTheme.bodyMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: channelColumnWidth,
              child: Text(
                'Channel',
                style: textTheme.titleSmall?.copyWith(
                  color: CrispyOverhaulTokens.textSecondary,
                ),
              ),
            ),
            ...guide.timeSlots.map(
              (String slot) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: CrispyOverhaulTokens.small,
                  ),
                  child: DecoratedBox(
                    decoration: CrispyShellRoles.infoPlateDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CrispyOverhaulTokens.small,
                        vertical: CrispyOverhaulTokens.compact,
                      ),
                      child: Text(
                        slot,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        ...visibleRows.map(
          (LiveTvGuideRowDetail row) => Padding(
            padding: const EdgeInsets.only(bottom: CrispyOverhaulTokens.small),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: channelColumnWidth,
                  child: Text(
                    '${row.channelNumber} ${row.channelName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color:
                          row.channelNumber == selectedChannelNumber
                              ? CrispyOverhaulTokens.textPrimary
                              : CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                ),
                ...guide.timeSlots.map((String slot) {
                  final LiveTvProgramDetail? program = _programForSlot(
                    row,
                    slot,
                  );
                  final bool selectedCell =
                      row.channelNumber == selectedChannelNumber &&
                      slot == guide.focusedSlot;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: CrispyOverhaulTokens.small,
                      ),
                      child: DecoratedBox(
                        decoration:
                            selectedCell
                                ? CrispyShellRoles.insetPanelDecoration()
                                : CrispyShellRoles.denseCardDecoration(),
                        child: Padding(
                          padding: cellPadding,
                          child: Text(
                            program?.title ?? 'No data',
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: cellStyle?.copyWith(
                              color:
                                  selectedCell
                                      ? CrispyOverhaulTokens.textPrimary
                                      : CrispyOverhaulTokens.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

LiveTvGuideRowDetail? _guideRowForChannel(
  List<LiveTvGuideRowDetail> rows,
  String channelNumber,
) {
  for (final LiveTvGuideRowDetail row in rows) {
    if (row.channelNumber == channelNumber) {
      return row;
    }
  }
  return null;
}

LiveTvProgramDetail? _programForSlot(LiveTvGuideRowDetail? row, String slot) {
  if (row == null) {
    return null;
  }
  for (final LiveTvProgramDetail program in row.programs) {
    if (program.slot == slot) {
      return program;
    }
  }
  return null;
}
