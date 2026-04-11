import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/data/mock_shell_catalog.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/section_selector.dart';
import 'package:flutter/material.dart';

class LiveTvView extends StatelessWidget {
  const LiveTvView({
    required this.panel,
    required this.group,
    required this.onSelectGroup,
    super.key,
  });

  final LiveTvPanel panel;
  final LiveTvGroup group;
  final ValueChanged<LiveTvGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    if (panel == LiveTvPanel.guide) {
      return _GuideView(group: group, onSelectGroup: onSelectGroup);
    }
    return _ChannelsView(group: group, onSelectGroup: onSelectGroup);
  }
}

class _ChannelsView extends StatelessWidget {
  const _ChannelsView({required this.group, required this.onSelectGroup});

  final LiveTvGroup group;
  final ValueChanged<LiveTvGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<ChannelEntry> channels = _channelsForGroup(group);
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CrispyOverhaulTokens.surfacePanel,
              borderRadius: BorderRadius.circular(
                CrispyOverhaulTokens.radiusSheet,
              ),
              border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
              itemBuilder:
                  (BuildContext context, int index) =>
                      _ChannelRow(entry: channels[index]),
              separatorBuilder:
                  (BuildContext context, int index) =>
                      const SizedBox(height: CrispyOverhaulTokens.small),
              itemCount: channels.length,
            ),
          ),
        ),
        const SizedBox(width: CrispyOverhaulTokens.large),
        Expanded(
          flex: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CrispyOverhaulTokens.surfacePanel,
              borderRadius: BorderRadius.circular(
                CrispyOverhaulTokens.radiusSheet,
              ),
              border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionSelector<LiveTvGroup>(
                    title: 'Channel groups',
                    values: LiveTvGroup.values,
                    selected: group,
                    labelBuilder: (LiveTvGroup value) => value.label,
                    keyBuilder:
                        (LiveTvGroup value) => 'live-tv-group-${value.name}',
                    onSelect: onSelectGroup,
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.large),
                  Text('Selected Channel', style: textTheme.titleLarge),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  Text(
                    channels.first.name,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: CrispyOverhaulTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.small),
                  Text(
                    'Midnight Bulletin  •  No autoplay on focus',
                    style: textTheme.bodyLarge?.copyWith(
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.large),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CrispyOverhaulTokens.surfaceHighlight,
                        borderRadius: BorderRadius.circular(
                          CrispyOverhaulTokens.radiusSheet,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Video preview / metadata stage',
                          style: TextStyle(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.entry});

  final ChannelEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CrispyOverhaulTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Row(
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
            Text(entry.timeRange, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _GuideView extends StatelessWidget {
  const _GuideView({required this.group, required this.onSelectGroup});

  final LiveTvGroup group;
  final ValueChanged<LiveTvGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CrispyOverhaulTokens.surfacePanel,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
        border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionSelector<LiveTvGroup>(
              title: 'Guide groups',
              values: LiveTvGroup.values,
              selected: group,
              labelBuilder: (LiveTvGroup value) => value.label,
              keyBuilder:
                  (LiveTvGroup value) => 'live-tv-guide-group-${value.name}',
              onSelect: onSelectGroup,
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            ...guideRows.map((List<String> row) => _GuideMatrixRow(cells: row)),
          ],
        ),
      ),
    );
  }
}

List<ChannelEntry> _channelsForGroup(LiveTvGroup group) {
  switch (group) {
    case LiveTvGroup.allChannels:
      return liveTvChannels;
    case LiveTvGroup.favorites:
      return liveTvChannels.take(2).toList(growable: false);
    case LiveTvGroup.news:
      return <ChannelEntry>[liveTvChannels[0]];
    case LiveTvGroup.sports:
      return <ChannelEntry>[liveTvChannels[1]];
    case LiveTvGroup.movies:
      return <ChannelEntry>[liveTvChannels[2]];
    case LiveTvGroup.kids:
      return <ChannelEntry>[liveTvChannels[3]];
  }
}

class _GuideMatrixRow extends StatelessWidget {
  const _GuideMatrixRow({required this.cells});

  final List<String> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CrispyOverhaulTokens.small),
      child: Row(
        children: cells
            .map(
              (String cell) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    right: CrispyOverhaulTokens.small,
                  ),
                  padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
                  color: CrispyOverhaulTokens.surfaceRaised,
                  child: Text(
                    cell,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CrispyOverhaulTokens.textPrimary,
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
