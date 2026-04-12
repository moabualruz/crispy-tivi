import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_artwork.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
import 'package:flutter/material.dart';

class SearchView extends StatefulWidget {
  const SearchView({required this.content, super.key});

  final ShellContentSnapshot content;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  int _selectedGroupIndex = 0;
  int _selectedResultIndex = 0;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<SearchResultGroup> groups = widget.content.searchGroups;
    final int selectedGroupIndex =
        _selectedGroupIndex < 0 || _selectedGroupIndex >= groups.length
            ? 0
            : _selectedGroupIndex;
    final SearchResultGroup selectedGroup = groups[selectedGroupIndex];
    final int selectedResultIndex =
        _selectedResultIndex < 0 ||
                _selectedResultIndex >= selectedGroup.results.length
            ? 0
            : _selectedResultIndex;
    final ShelfItem selectedResult = selectedGroup.results[selectedResultIndex];
    final _SearchHandoffCopy handoff = _handoffFor(
      selectedGroup,
      selectedResult,
    );
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DecoratedBox(
          decoration: CrispyShellRoles.panelDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Search', style: textTheme.headlineLarge),
                      const SizedBox(height: CrispyOverhaulTokens.medium),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Text(
                          'Search live channels, films, and series from the active content catalog.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.large),
                      const _SearchFieldPlate(),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      Text(
                        'Global content scope. Results open into Live TV and Media, not Settings.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.section),
                SizedBox(
                  width: 320,
                  child: _SearchHandoffPanel(
                    selectedGroup: selectedGroup,
                    selectedResult: selectedResult,
                    handoff: handoff,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.section),
        for (final (int groupIndex, SearchResultGroup group)
            in groups.indexed) ...<Widget>[
          _SearchGroup(
            group: group,
            groupIndex: groupIndex,
            selectedResultIndex:
                groupIndex == selectedGroupIndex ? selectedResultIndex : -1,
            onSelectResult: (int resultIndex) {
              setState(() {
                _selectedGroupIndex = groupIndex;
                _selectedResultIndex = resultIndex;
              });
            },
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
        ],
      ],
    );
  }

  _SearchHandoffCopy _handoffFor(SearchResultGroup group, ShelfItem item) {
    switch (group.title) {
      case 'Live TV':
        return _SearchHandoffCopy(
          domainLabel: 'Live TV',
          actionLabel: 'Open channel',
        );
      case 'Movies':
        return _SearchHandoffCopy(
          domainLabel: 'Movies',
          actionLabel: 'Open movie',
        );
      case 'Series':
        return _SearchHandoffCopy(
          domainLabel: 'Series',
          actionLabel: 'Open series',
        );
    }

    return _SearchHandoffCopy(
      domainLabel: group.title,
      actionLabel: 'Open result',
    );
  }
}

class _SearchFieldPlate extends StatelessWidget {
  const _SearchFieldPlate();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.searchFieldDecoration(),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.large,
          vertical: CrispyOverhaulTokens.medium,
        ),
        child: Row(
          children: <Widget>[
            ShellIconGraphic(
              icon: Icons.search,
              role: ShellIconRole.row,
            ),
            SizedBox(width: CrispyOverhaulTokens.small),
            Expanded(
              child: Text(
                'Search live and media titles',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: CrispyOverhaulTokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchGroup extends StatelessWidget {
  const _SearchGroup({
    required this.group,
    required this.groupIndex,
    required this.selectedResultIndex,
    required this.onSelectResult,
  });

  final SearchResultGroup group;
  final int groupIndex;
  final int selectedResultIndex;
  final ValueChanged<int> onSelectResult;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            ShellIconPlate(
              icon: CrispyShellIcons.searchGroup(group.title),
              role: ShellIconRole.row,
            ),
            const SizedBox(width: CrispyOverhaulTokens.small),
            Text(group.title, style: textTheme.titleLarge),
            const SizedBox(width: CrispyOverhaulTokens.small),
            Text(
              '${group.results.length} result${group.results.length == 1 ? '' : 's'}',
              style: textTheme.bodyMedium?.copyWith(
                color: CrispyOverhaulTokens.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: CrispyOverhaulTokens.medium),
        DecoratedBox(
          decoration: CrispyShellRoles.searchResultDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
            child: Wrap(
              spacing: CrispyOverhaulTokens.medium,
              runSpacing: CrispyOverhaulTokens.medium,
              children: <Widget>[
                for (final (int resultIndex, ShelfItem item)
                    in group.results.indexed)
                  _SearchResultCard(
                    item: item,
                    itemKey: Key('search-result-$groupIndex-$resultIndex'),
                    selected: resultIndex == selectedResultIndex,
                    onTap: () => onSelectResult(resultIndex),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.item,
    required this.itemKey,
    required this.selected,
    required this.onTap,
  });

  final ShelfItem item;
  final Key itemKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: itemKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
          child: DecoratedBox(
            decoration:
                selected
                    ? CrispyShellRoles.searchResultDecoration()
                    : CrispyShellRoles.shelfCardDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 1.55,
                    child: ShellArtwork(
                      source: item.artwork,
                      borderRadius: BorderRadius.circular(
                        CrispyOverhaulTokens.radiusCard,
                      ),
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.small),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: CrispyOverhaulTokens.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.compact),
                  Text(
                    item.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHandoffPanel extends StatelessWidget {
  const _SearchHandoffPanel({
    required this.selectedGroup,
    required this.selectedResult,
    required this.handoff,
  });

  final SearchResultGroup selectedGroup;
  final ShelfItem selectedResult;
  final _SearchHandoffCopy handoff;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Selected result',
              style: textTheme.titleMedium?.copyWith(
                color: CrispyOverhaulTokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            AspectRatio(
              aspectRatio: 1.55,
              child: ShellArtwork(
                source: selectedResult.artwork,
                borderRadius: BorderRadius.circular(
                  CrispyOverhaulTokens.radiusCard,
                ),
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Row(
              children: <Widget>[
                ShellIconPlate(
                  icon: CrispyShellIcons.searchGroup(handoff.domainLabel),
                  role: ShellIconRole.row,
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: Text(
                    handoff.domainLabel,
                    key: const Key('search-handoff-domain'),
                    style: textTheme.labelLarge?.copyWith(
                      color: CrispyOverhaulTokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              selectedResult.title,
              key: const Key('search-handoff-title'),
              style: textTheme.headlineSmall?.copyWith(
                color: CrispyOverhaulTokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              selectedResult.caption,
              key: const Key('search-handoff-caption'),
              style: textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            DecoratedBox(
              decoration: CrispyShellRoles.inputFieldDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispyOverhaulTokens.medium,
                  vertical: CrispyOverhaulTokens.medium,
                ),
                child: Row(
                  children: <Widget>[
                    ShellIconGraphic(
                      icon: CrispyShellIcons.searchAction(handoff.actionLabel),
                      role: ShellIconRole.row,
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                    const SizedBox(width: CrispyOverhaulTokens.small),
                    Expanded(
                      child: Text(
                        handoff.actionLabel,
                        key: const Key('search-handoff-action'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHandoffCopy {
  const _SearchHandoffCopy({
    required this.domainLabel,
    required this.actionLabel,
  });

  final String domainLabel;
  final String actionLabel;
}
