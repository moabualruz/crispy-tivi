import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:flutter/material.dart';

class LiveTvView extends StatelessWidget {
  const LiveTvView({
    required this.content,
    required this.availableGroups,
    required this.panel,
    required this.group,
    required this.onSelectGroup,
    super.key,
  });

  final MockShellContentSnapshot content;
  final List<LiveTvGroup> availableGroups;
  final LiveTvPanel panel;
  final LiveTvGroup group;
  final ValueChanged<LiveTvGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    if (panel == LiveTvPanel.guide) {
      return _GuideView(
        content: content,
        availableGroups: availableGroups,
        group: group,
        onSelectGroup: onSelectGroup,
      );
    }
    return _ChannelsView(
      content: content,
      availableGroups: availableGroups,
      group: group,
      onSelectGroup: onSelectGroup,
    );
  }
}

class _ChannelsView extends StatelessWidget {
  const _ChannelsView({
    required this.content,
    required this.availableGroups,
    required this.group,
    required this.onSelectGroup,
  });

  final MockShellContentSnapshot content;
  final List<LiveTvGroup> availableGroups;
  final LiveTvGroup group;
  final ValueChanged<LiveTvGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final List<ChannelEntry> channels = _channelsForGroup(
      content.liveTvChannels,
      group,
    );
    final ChannelEntry selectedChannel = channels.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 4,
          child: DecoratedBox(
            decoration: CrispyShellRoles.panelDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionHeader(
                    title: 'Channels',
                    subtitle: 'Dense channel rail with group-aware filtering.',
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  _GroupRail(
                    title: 'Channel groups',
                    values: availableGroups,
                    selected: group,
                    labelBuilder: (LiveTvGroup value) => value.label,
                    keyBuilder:
                        (LiveTvGroup value) => 'live-tv-group-${value.name}',
                    onSelect: onSelectGroup,
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.large),
                  Expanded(
                    child: ListView.separated(
                      itemBuilder:
                          (BuildContext context, int index) => _ChannelRow(
                            entry: channels[index],
                            selected: index == 0,
                          ),
                      separatorBuilder:
                          (BuildContext context, int index) => const SizedBox(
                            height: CrispyOverhaulTokens.small,
                          ),
                      itemCount: channels.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: CrispyOverhaulTokens.large),
        Expanded(
          flex: 8,
          child: Column(
            children: <Widget>[
              Expanded(
                child: DecoratedBox(
                  decoration: CrispyShellRoles.panelDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
                    child: _ChannelDetailPane(
                      selectedChannel: selectedChannel,
                      group: group,
                      guideRows: content.guideRows,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.large),
              SizedBox(
                height: 214,
                child: _GuideSnapshotPanel(rows: content.guideRows),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideView extends StatelessWidget {
  const _GuideView({
    required this.content,
    required this.availableGroups,
    required this.group,
    required this.onSelectGroup,
  });

  final MockShellContentSnapshot content;
  final List<LiveTvGroup> availableGroups;
  final LiveTvGroup group;
  final ValueChanged<LiveTvGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final List<ChannelEntry> channels = _channelsForGroup(
      content.liveTvChannels,
      group,
    );
    final ChannelEntry selectedChannel = channels.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 304,
          child: DecoratedBox(
            decoration: CrispyShellRoles.panelDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionHeader(
                    title: 'Guide groups',
                    subtitle:
                        'Focus stays in the Settings-owned guide lane, not playback.',
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  _GroupRail(
                    title: 'Browse groups',
                    values: availableGroups,
                    selected: group,
                    labelBuilder: (LiveTvGroup value) => value.label,
                    keyBuilder:
                        (LiveTvGroup value) => 'live-tv-group-${value.name}',
                    onSelect: onSelectGroup,
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.large),
                  _InfoBadge(
                    label: 'Selected channel',
                    value: '${selectedChannel.number} ${selectedChannel.name}',
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.small),
                  _InfoBadge(
                    label: 'Program',
                    value: selectedChannel.program,
                  ),
                ],
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
                      guideRows: content.guideRows,
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
                    child: _GuideMatrix(rows: content.guideRows),
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
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final String Function(T value) keyBuilder;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
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
        ...values.map(
          (T value) => Padding(
            padding: const EdgeInsets.only(bottom: CrispyOverhaulTokens.small),
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
  });

  final Key itemKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: itemKey,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: CrispyOverhaulTokens.medium,
            vertical: CrispyOverhaulTokens.small,
          ),
          decoration:
              selected
                  ? BoxDecoration(
                    color: CrispyOverhaulTokens.surfaceHighlight,
                    borderRadius: BorderRadius.circular(
                      CrispyOverhaulTokens.radiusCard,
                    ),
                    border: Border.all(color: CrispyOverhaulTokens.accentFocus),
                  )
                  : BoxDecoration(
                    color: CrispyOverhaulTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(
                      CrispyOverhaulTokens.radiusCard,
                    ),
                    border: Border.all(
                      color: CrispyOverhaulTokens.borderStrong,
                    ),
                  ),
          child: Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      selected
                          ? CrispyOverhaulTokens.accentFocus
                          : CrispyOverhaulTokens.textSecondary,
                ),
              ),
              const SizedBox(width: CrispyOverhaulTokens.small),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    color:
                        selected
                            ? CrispyOverhaulTokens.navSelectedText
                            : CrispyOverhaulTokens.textPrimary,
                  ),
                ),
              ),
              Text(
                selected ? 'Active' : 'Browse',
                style: textTheme.bodySmall?.copyWith(
                  color: CrispyOverhaulTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, required this.value});

  final String label;
  final String value;

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
            Text(value, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.entry, required this.selected});

  final ChannelEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
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
              width: 72,
              child: Text(
                entry.number,
                style: textTheme.titleMedium?.copyWith(
                  color: CrispyOverhaulTokens.accentFocus,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(entry.name, style: textTheme.titleMedium),
                  const SizedBox(height: CrispyOverhaulTokens.compact),
                  Text(entry.program, style: textTheme.bodyMedium),
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
    );
  }
}

class _ChannelDetailPane extends StatelessWidget {
  const _ChannelDetailPane({
    required this.selectedChannel,
    required this.group,
    required this.guideRows,
  });

  final ChannelEntry selectedChannel;
  final LiveTvGroup group;
  final List<List<String>> guideRows;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<String> headerRow = guideRows.isNotEmpty ? guideRows.first : <String>[];
    final List<String> nextRow = guideRows.length > 1 ? guideRows[1] : <String>[];
    final String nextProgram =
        nextRow.length > 2 ? nextRow[2] : 'Guide stays readable without autoplay';
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: CrispyOverhaulTokens.small,
            runSpacing: CrispyOverhaulTokens.small,
            children: <Widget>[
              const _InfoBadge(label: 'Live', value: 'Preview'),
              _InfoBadge(label: 'Group', value: group.label),
              Padding(
                padding: const EdgeInsets.only(
                  top: CrispyOverhaulTokens.compact,
                ),
                child: Text(
                  'Focus stays in the guide lane',
                  style: textTheme.bodySmall?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
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
                    'Focused detail lane',
                    style: textTheme.titleLarge?.copyWith(
                      color: CrispyOverhaulTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.compact),
                  Text(
                    '${selectedChannel.number} · ${selectedChannel.name}',
                    style: textTheme.bodyLarge?.copyWith(
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  DecoratedBox(
                    decoration: CrispyShellRoles.heroArtworkScrimDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        CrispyOverhaulTokens.medium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            selectedChannel.program,
                            style: textTheme.titleMedium?.copyWith(
                              color: CrispyOverhaulTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(
                            height: CrispyOverhaulTokens.compact,
                          ),
                          Text(
                            'Next: $nextProgram',
                            style: textTheme.bodyMedium?.copyWith(
                              color: CrispyOverhaulTokens.textSecondary,
                            ),
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
          Row(
            children: <Widget>[
              if (headerRow.isNotEmpty)
                ...headerRow
                    .skip(1)
                    .map(
                      (String slot) => Padding(
                        padding: const EdgeInsets.only(
                          right: CrispyOverhaulTokens.small,
                        ),
                        child: _InfoBadge(label: 'Slot', value: slot),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideSnapshotPanel extends StatelessWidget {
  const _GuideSnapshotPanel({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: _GuideMatrix(rows: rows),
      ),
    );
  }
}

class _GuidePreviewPane extends StatelessWidget {
  const _GuidePreviewPane({
    required this.selectedChannel,
    required this.guideRows,
  });

  final ChannelEntry selectedChannel;
  final List<List<String>> guideRows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxHeight < 240) {
          return _CompactGuidePreviewPane(
            selectedChannel: selectedChannel,
            guideRows: guideRows,
          );
        }
        return _ExpandedGuidePreviewPane(
          selectedChannel: selectedChannel,
          guideRows: guideRows,
        );
      },
    );
  }
}

class _ExpandedGuidePreviewPane extends StatelessWidget {
  const _ExpandedGuidePreviewPane({
    required this.selectedChannel,
    required this.guideRows,
  });

  final ChannelEntry selectedChannel;
  final List<List<String>> guideRows;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String nowSlot =
        guideRows.isNotEmpty && guideRows.first.isNotEmpty
            ? guideRows.first.first
            : 'Now';
    final String currentProgram =
        guideRows.length > 1 && guideRows[1].length > 1
            ? guideRows[1][1]
            : selectedChannel.program;
    final String nextProgram =
        guideRows.length > 1 && guideRows[1].length > 2
            ? guideRows[1][2]
            : 'No follow-up data';
    return DecoratedBox(
      decoration: CrispyShellRoles.previewStageDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _InfoBadge(label: 'Guide time', value: nowSlot),
                const SizedBox(width: CrispyOverhaulTokens.small),
                _InfoBadge(label: 'Channel', value: selectedChannel.number),
                const Spacer(),
                Text(
                  'Guide focus never starts playback',
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
                        'Focused guide detail',
                        style: textTheme.titleLarge?.copyWith(
                          color: CrispyOverhaulTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.compact),
                      Text(
                        currentProgram,
                        style: textTheme.bodyLarge?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      Text(
                        'Next: $nextProgram',
                        style: textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
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
    required this.guideRows,
  });

  final ChannelEntry selectedChannel;
  final List<List<String>> guideRows;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String nowSlot =
        guideRows.isNotEmpty && guideRows.first.isNotEmpty
            ? guideRows.first.first
            : 'Now';
    final String currentProgram =
        guideRows.length > 1 && guideRows[1].length > 1
            ? guideRows[1][1]
            : selectedChannel.program;
    return DecoratedBox(
      decoration: CrispyShellRoles.previewStageDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: CrispyOverhaulTokens.small,
              runSpacing: CrispyOverhaulTokens.small,
              children: <Widget>[
                _InfoBadge(label: 'Guide time', value: nowSlot),
                _InfoBadge(label: 'Channel', value: selectedChannel.number),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Text(
              currentProgram,
              style: textTheme.titleMedium?.copyWith(
                color: CrispyOverhaulTokens.textPrimary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              'Guide focus never starts playback',
              style: textTheme.bodySmall?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideMatrix extends StatelessWidget {
  const _GuideMatrix({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<String> headerRow = rows.first;
    final List<List<String>> dataRows = rows.skip(1).toList(growable: false);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 160,
              child: Text(
                'Channel',
                style: textTheme.titleSmall?.copyWith(
                  color: CrispyOverhaulTokens.textSecondary,
                ),
              ),
            ),
            ...headerRow
                .skip(1)
                .map(
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
        ...dataRows.asMap().entries.map(
          (MapEntry<int, List<String>> entry) => Padding(
            padding: const EdgeInsets.only(bottom: CrispyOverhaulTokens.small),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: Text(
                    entry.value.first,
                    style: textTheme.titleSmall?.copyWith(
                      color:
                          entry.key == 0
                              ? CrispyOverhaulTokens.textPrimary
                              : CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                ),
                ...entry.value
                    .skip(1)
                    .map(
                      (String cell) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: CrispyOverhaulTokens.small,
                          ),
                          child: DecoratedBox(
                            decoration:
                                entry.key == 0
                                    ? CrispyShellRoles.insetPanelDecoration()
                                    : CrispyShellRoles.denseCardDecoration(),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                CrispyOverhaulTokens.small,
                              ),
                              child: Text(
                                cell,
                                style: textTheme.bodyMedium?.copyWith(
                                  color:
                                      entry.key == 0
                                          ? CrispyOverhaulTokens.textPrimary
                                          : CrispyOverhaulTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

List<ChannelEntry> _channelsForGroup(
  List<ChannelEntry> channels,
  LiveTvGroup group,
) {
  switch (group) {
    case LiveTvGroup.allChannels:
      return channels;
    case LiveTvGroup.favorites:
      return channels.take(2).toList(growable: false);
    case LiveTvGroup.news:
      return <ChannelEntry>[channels[0]];
    case LiveTvGroup.sports:
      return <ChannelEntry>[channels[1]];
    case LiveTvGroup.movies:
      return <ChannelEntry>[channels[2]];
    case LiveTvGroup.kids:
      return <ChannelEntry>[channels[3]];
  }
}
