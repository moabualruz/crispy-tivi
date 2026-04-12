import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/settings_rows.dart';
import 'package:flutter/material.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.panel,
    required this.content,
    required this.selectedSourceIndex,
    required this.sourceWizardActive,
    required this.sourceWizardStep,
    required this.searchQuery,
    required this.highlightedLeaf,
    required this.onUpdateSearchQuery,
    required this.onClearSearch,
    required this.onOpenSettingsLeaf,
    required this.onSelectSource,
    required this.onStartAddSource,
    required this.onStartReconnect,
    required this.onSelectWizardStep,
    required this.onAdvanceWizard,
    required this.onRetreatWizard,
    super.key,
  });

  final SettingsPanel panel;
  final ShellContentSnapshot content;
  final int selectedSourceIndex;
  final bool sourceWizardActive;
  final SourceWizardStep sourceWizardStep;
  final String searchQuery;
  final String? highlightedLeaf;
  final ValueChanged<String> onUpdateSearchQuery;
  final VoidCallback onClearSearch;
  final void Function({
    required SettingsPanel panel,
    required String leafLabel,
    int? sourceIndex,
  })
  onOpenSettingsLeaf;
  final ValueChanged<int> onSelectSource;
  final VoidCallback onStartAddSource;
  final VoidCallback onStartReconnect;
  final ValueChanged<SourceWizardStep> onSelectWizardStep;
  final VoidCallback onAdvanceWizard;
  final VoidCallback onRetreatWizard;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.searchQuery,
  );

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = widget.searchQuery.trim();
    final List<_SettingsSearchMatch> matches =
        query.isEmpty
            ? const <_SettingsSearchMatch>[]
            : _findMatches(widget.content, query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SettingsSearchBar(
          controller: _searchController,
          searchQuery: widget.searchQuery,
          onChanged: widget.onUpdateSearchQuery,
          onClear: widget.onClearSearch,
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        Expanded(
          child: switch ((
            query.isEmpty,
            widget.highlightedLeaf != null,
            matches.isEmpty,
          )) {
            (true, _, _) => _buildCurrentPanel(),
            (false, true, _) => _buildOpenedLeaf(query),
            (false, false, true) => _SettingsSearchEmptyState(query: query),
            _ => _SettingsSearchResults(
              query: query,
              matches: matches,
              onActivate: widget.onOpenSettingsLeaf,
            ),
          },
        ),
      ],
    );
  }

  Widget _buildCurrentPanel() {
    return _buildPanelView(
      panel: widget.panel,
      title: widget.panel.label,
      description: _panelDescription(widget.panel),
      matchDescription:
          'Search stays local to Settings and activates an exact leaf inside this grouped hierarchy.',
    );
  }

  Widget _buildOpenedLeaf(String query) {
    final _SettingsSearchMatch? activeMatch = _matchForOpenedLeaf(
      content: widget.content,
      panel: widget.panel,
      highlightedLeaf: widget.highlightedLeaf,
      selectedSourceIndex: widget.selectedSourceIndex,
    );
    final String openedLabel =
        activeMatch?.displayLabel ?? widget.highlightedLeaf ?? query;
    return _buildPanelView(
      panel: widget.panel,
      title: widget.panel.label,
      description: 'Search opened: $openedLabel.',
      matchDescription:
          'Exact leaf active: $openedLabel. Highlight stays inside the grouped Settings hierarchy.',
      highlightedItemIndex: activeMatch?.itemIndex,
      forcedSourceIndex: activeMatch?.sourceIndex,
    );
  }

  Widget _buildPanelView({
    required SettingsPanel panel,
    required String title,
    required String description,
    required String matchDescription,
    int? highlightedItemIndex,
    int? forcedSourceIndex,
  }) {
    switch (panel) {
      case SettingsPanel.general:
        return _SettingsSectionView(
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: SettingsRows(
            items: widget.content.generalSettings,
            sectionLabel: 'General settings',
            sectionSummary:
                'Keep launch and recommendation behavior inside the utility lane.',
            highlightedItemIndex: highlightedItemIndex,
          ),
        );
      case SettingsPanel.playback:
        return _SettingsSectionView(
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: SettingsRows(
            items: widget.content.playbackSettings,
            sectionLabel: 'Playback settings',
            sectionSummary:
                'Playback defaults should be calm, explicit, and easy to unwind.',
            highlightedItemIndex: highlightedItemIndex,
          ),
        );
      case SettingsPanel.sources:
        return _SettingsSourceLane(
          title: title,
          description: description,
          matchDescription: matchDescription,
          sources: widget.content.sourceHealthItems,
          selectedSourceIndex: forcedSourceIndex ?? widget.selectedSourceIndex,
          wizardActive:
              widget.sourceWizardActive && highlightedItemIndex == null,
          wizardSteps: widget.content.sourceWizardSteps,
          activeWizardStep: widget.sourceWizardStep,
          onSelectSource: widget.onSelectSource,
          onStartAddSource: widget.onStartAddSource,
          onStartReconnect: widget.onStartReconnect,
          onSelectWizardStep: widget.onSelectWizardStep,
          onAdvanceWizard: widget.onAdvanceWizard,
          onRetreatWizard: widget.onRetreatWizard,
        );
      case SettingsPanel.appearance:
        return _SettingsSectionView(
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: SettingsRows(
            items: widget.content.appearanceSettings,
            sectionLabel: 'Appearance settings',
            sectionSummary:
                'Keep readability, density, and surface treatment in one place.',
            highlightedItemIndex: highlightedItemIndex,
          ),
        );
      case SettingsPanel.system:
        return _SettingsSectionView(
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: SettingsRows(
            items: widget.content.systemSettings,
            sectionLabel: 'System settings',
            sectionSummary:
                'System controls stay grouped so diagnostics never feel detached.',
            highlightedItemIndex: highlightedItemIndex,
          ),
        );
    }
  }
}

class _SettingsSearchBar extends StatelessWidget {
  const _SettingsSearchBar({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: CrispyShellRoles.iconPlateDecoration(),
                  child: const Icon(
                    Icons.search,
                    color: CrispyOverhaulTokens.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Settings search', style: textTheme.headlineSmall),
                      const SizedBox(height: CrispyOverhaulTokens.compact),
                      Text(
                        'Search stays local to Settings and opens an exact leaf only after activating a result.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (searchQuery.isNotEmpty) ...<Widget>[
                  const SizedBox(width: CrispyOverhaulTokens.medium),
                  TextButton(
                    onPressed: onClear,
                    style: CrispyShellRoles.actionButtonStyle(emphasis: false),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            DecoratedBox(
              decoration: CrispyShellRoles.searchFieldDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispyOverhaulTokens.large,
                  vertical: CrispyOverhaulTokens.medium,
                ),
                child: TextField(
                  key: const Key('settings-search-field'),
                  controller: controller,
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText:
                        'Search General, Playback, Sources, Appearance, or System',
                    hintStyle: TextStyle(
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                  style: textTheme.bodyLarge?.copyWith(
                    color: CrispyOverhaulTokens.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              'No global search here. This only searches the grouped Settings hierarchy.',
              style: textTheme.bodyMedium?.copyWith(
                color: CrispyOverhaulTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSearchResults extends StatelessWidget {
  const _SettingsSearchResults({
    required this.query,
    required this.matches,
    required this.onActivate,
  });

  final String query;
  final List<_SettingsSearchMatch> matches;
  final void Function({
    required SettingsPanel panel,
    required String leafLabel,
    int? sourceIndex,
  })
  onActivate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Search results',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              'Activate a result to open the exact leaf inside Settings.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Expanded(
              child: ListView.separated(
                itemCount: matches.length,
                separatorBuilder:
                    (BuildContext context, int index) =>
                        const SizedBox(height: CrispyOverhaulTokens.small),
                itemBuilder: (BuildContext context, int index) {
                  final _SettingsSearchMatch match = matches[index];
                  return TextButton(
                    key: Key('settings-search-hit-$index'),
                    onPressed:
                        () => onActivate(
                          panel: match.panel,
                          leafLabel: match.leafKey,
                          sourceIndex: match.sourceIndex,
                        ),
                    style: CrispyShellRoles.selectorButtonStyle(
                      selected: false,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CrispyOverhaulTokens.medium,
                        vertical: CrispyOverhaulTokens.medium,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: CrispyShellRoles.iconPlateDecoration(),
                            child: Icon(
                              match.icon,
                              color: CrispyOverhaulTokens.textSecondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: CrispyOverhaulTokens.medium),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  match.displayLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(
                                  height: CrispyOverhaulTokens.compact,
                                ),
                                Text(
                                  '${match.panel.label} • ${match.supportingText(query)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: CrispyOverhaulTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: CrispyOverhaulTokens.medium),
                          const Icon(
                            Icons.chevron_right,
                            color: CrispyOverhaulTokens.textMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionView extends StatelessWidget {
  const _SettingsSectionView({
    required this.title,
    required this.description,
    required this.matchDescription,
    required this.child,
  });

  final String title;
  final String description;
  final String matchDescription;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DecoratedBox(
          decoration: CrispyShellRoles.panelDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: CrispyShellRoles.iconPlateDecoration(),
                      child: const Icon(
                        Icons.tune_outlined,
                        size: 20,
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: CrispyOverhaulTokens.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: CrispyOverhaulTokens.compact),
                          Text(
                            description,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: CrispyOverhaulTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CrispyOverhaulTokens.medium),
                DecoratedBox(
                  decoration: CrispyShellRoles.infoPlateDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispyOverhaulTokens.medium,
                      vertical: CrispyOverhaulTokens.small,
                    ),
                    child: Text(
                      matchDescription,
                      style: const TextStyle(
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        child,
      ],
    );
  }
}

class _SettingsSourceLane extends StatelessWidget {
  const _SettingsSourceLane({
    required this.title,
    required this.description,
    required this.matchDescription,
    required this.sources,
    required this.selectedSourceIndex,
    required this.wizardActive,
    required this.wizardSteps,
    required this.activeWizardStep,
    required this.onSelectSource,
    required this.onStartAddSource,
    required this.onStartReconnect,
    required this.onSelectWizardStep,
    required this.onAdvanceWizard,
    required this.onRetreatWizard,
  });

  final String title;
  final String description;
  final String matchDescription;
  final List<SourceHealthItem> sources;
  final int selectedSourceIndex;
  final bool wizardActive;
  final List<SourceWizardStepContent> wizardSteps;
  final SourceWizardStep activeWizardStep;
  final ValueChanged<int> onSelectSource;
  final VoidCallback onStartAddSource;
  final VoidCallback onStartReconnect;
  final ValueChanged<SourceWizardStep> onSelectWizardStep;
  final VoidCallback onAdvanceWizard;
  final VoidCallback onRetreatWizard;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final SourceHealthItem selectedSource = sources[selectedSourceIndex];
    final SourceWizardStepContent activeStep = wizardSteps.firstWhere(
      (SourceWizardStepContent item) => item.step == activeWizardStep,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: CrispyShellRoles.panelDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: textTheme.titleLarge),
                const SizedBox(height: CrispyOverhaulTokens.compact),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: CrispyOverhaulTokens.compact),
                Text(
                  matchDescription,
                  style: textTheme.bodySmall?.copyWith(
                    color: CrispyOverhaulTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 300,
                child: _SettingsSourceListPane(
                  sources: sources,
                  selectedSourceIndex: selectedSourceIndex,
                  onSelectSource: onSelectSource,
                  onStartAddSource: onStartAddSource,
                ),
              ),
              const SizedBox(width: CrispyOverhaulTokens.medium),
              if (wizardActive) ...<Widget>[
                SizedBox(
                  width: 240,
                  child: _SettingsWizardRail(
                    steps: wizardSteps,
                    activeStep: activeWizardStep,
                    onSelectStep: onSelectWizardStep,
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.medium),
              ],
              Expanded(
                child:
                    wizardActive
                        ? _SettingsWizardPane(
                          step: activeStep,
                          onAdvance: onAdvanceWizard,
                          onRetreat: onRetreatWizard,
                        )
                        : _SettingsSourceDetailPane(
                          source: selectedSource,
                          onStartReconnect: onStartReconnect,
                          onStartAddSource: onStartAddSource,
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSourceListPane extends StatelessWidget {
  const _SettingsSourceListPane({
    required this.sources,
    required this.selectedSourceIndex,
    required this.onSelectSource,
    required this.onStartAddSource,
  });

  final List<SourceHealthItem> sources;
  final int selectedSourceIndex;
  final ValueChanged<int> onSelectSource;
  final VoidCallback onStartAddSource;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Connected sources',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              '${sources.length} active sources',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            TextButton(
              key: const Key('sources-add-button'),
              onPressed: onStartAddSource,
              style: CrispyShellRoles.actionButtonStyle(emphasis: true),
              child: const Text('Add source'),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (
                    int index = 0;
                    index < sources.length;
                    index += 1
                  ) ...<Widget>[
                    _SettingsSourceListItem(
                      source: sources[index],
                      selected: selectedSourceIndex == index,
                      onSelect: () => onSelectSource(index),
                    ),
                    if (index < sources.length - 1)
                      const SizedBox(height: CrispyOverhaulTokens.small),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSourceListItem extends StatelessWidget {
  const _SettingsSourceListItem({
    required this.source,
    required this.selected,
    required this.onSelect,
  });

  final SourceHealthItem source;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: Key('source-item-${source.name}'),
      onPressed: onSelect,
      style: CrispyShellRoles.selectorButtonStyle(selected: selected).copyWith(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: CrispyOverhaulTokens.medium,
            vertical: CrispyOverhaulTokens.medium,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  source.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        selected
                            ? CrispyOverhaulTokens.navSelectedText
                            : CrispyOverhaulTokens.textPrimary,
                  ),
                ),
              ),
              Text(
                source.status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      selected
                          ? CrispyOverhaulTokens.navSelectedText
                          : CrispyOverhaulTokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: CrispyOverhaulTokens.compact),
          Text(
            source.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  selected
                      ? CrispyOverhaulTokens.navSelectedText
                      : CrispyOverhaulTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsWizardRail extends StatelessWidget {
  const _SettingsWizardRail({
    required this.steps,
    required this.activeStep,
    required this.onSelectStep,
  });

  final List<SourceWizardStepContent> steps;
  final SourceWizardStep activeStep;
  final ValueChanged<SourceWizardStep> onSelectStep;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Wizard steps', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Expanded(
              child: ListView.separated(
                itemCount: steps.length,
                separatorBuilder:
                    (BuildContext context, int index) =>
                        const SizedBox(height: CrispyOverhaulTokens.small),
                itemBuilder: (BuildContext context, int index) {
                  final SourceWizardStepContent step = steps[index];
                  final bool selected = step.step == activeStep;
                  return TextButton(
                    key: Key('source-wizard-step-${step.step.label}'),
                    onPressed: () => onSelectStep(step.step),
                    style: CrispyShellRoles.selectorButtonStyle(
                      selected: selected,
                    ).copyWith(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(
                          horizontal: CrispyOverhaulTokens.medium,
                          vertical: CrispyOverhaulTokens.medium,
                        ),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${index + 1}. ${step.step.label}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              selected
                                  ? CrispyOverhaulTokens.navSelectedText
                                  : CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsWizardPane extends StatelessWidget {
  const _SettingsWizardPane({
    required this.step,
    required this.onAdvance,
    required this.onRetreat,
  });

  final SourceWizardStepContent step;
  final VoidCallback onAdvance;
  final VoidCallback onRetreat;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: CrispyShellRoles.iconPlateDecoration(),
                    child: const Icon(
                      Icons.source_outlined,
                      size: 18,
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: CrispyOverhaulTokens.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          step.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.compact),
                        Text(
                          step.summary,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              DecoratedBox(
                decoration: CrispyShellRoles.inputFieldDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final String field in step.fieldLabels) ...<Widget>[
                        _DetailField(
                          label: field,
                          value: 'Enter ${field.toLowerCase()}',
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.small),
                      ],
                      for (final String helper in step.helperLines) ...<Widget>[
                        Text(
                          helper,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: CrispyOverhaulTokens.textMuted),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.small),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              Row(
                children: <Widget>[
                  TextButton(
                    key: const Key('source-wizard-primary-action'),
                    onPressed: onAdvance,
                    style: CrispyShellRoles.actionButtonStyle(emphasis: true),
                    child: Text(step.primaryAction),
                  ),
                  const SizedBox(width: CrispyOverhaulTokens.small),
                  TextButton(
                    key: const Key('source-wizard-secondary-action'),
                    onPressed: onRetreat,
                    style: CrispyShellRoles.actionButtonStyle(emphasis: false),
                    child: Text(step.secondaryAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSourceDetailPane extends StatelessWidget {
  const _SettingsSourceDetailPane({
    required this.source,
    required this.onStartReconnect,
    required this.onStartAddSource,
  });

  final SourceHealthItem source;
  final VoidCallback onStartReconnect;
  final VoidCallback onStartAddSource;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          source.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.compact),
                        Text(
                          source.summary,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: CrispyShellRoles.iconPlateDecoration(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispyOverhaulTokens.medium,
                      vertical: CrispyOverhaulTokens.small,
                    ),
                    child: Text(
                      source.status,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _sourceStatusColor(source.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              DecoratedBox(
                decoration: CrispyShellRoles.insetPanelDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
                  child: Column(
                    children: <Widget>[
                      _DetailField(
                        label: 'Source type',
                        value: source.sourceType,
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      _DetailField(label: 'Endpoint', value: source.endpoint),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      _DetailField(label: 'Last sync', value: source.lastSync),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              Text(
                'Capabilities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: CrispyOverhaulTokens.small),
              DecoratedBox(
                decoration: CrispyShellRoles.inputFieldDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
                  child: Column(
                    children: source.capabilities
                        .map(
                          (String capability) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: CrispyOverhaulTokens.small,
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: CrispyOverhaulTokens.textMuted,
                                ),
                                const SizedBox(width: CrispyOverhaulTokens.small),
                                Expanded(
                                  child: Text(
                                    capability,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              DecoratedBox(
                decoration: CrispyShellRoles.infoPlateDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Source actions',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      Text(
                        'Reconnect uses the same Settings-owned wizard lane; import stays a separate explicit step.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.medium),
                      Row(
                        children: <Widget>[
                          SizedBox(
                            key: const Key('sources-primary-action'),
                            child: TextButton(
                              onPressed:
                                  source.status == 'Needs auth'
                                      ? onStartReconnect
                                      : onStartAddSource,
                              style: CrispyShellRoles.actionButtonStyle(
                                emphasis: true,
                              ),
                              child: Text(source.primaryAction),
                            ),
                          ),
                          const SizedBox(width: CrispyOverhaulTokens.small),
                          SizedBox(
                            key: const Key('sources-secondary-action'),
                            child: TextButton(
                              onPressed: onStartAddSource,
                              style: CrispyShellRoles.actionButtonStyle(
                                emphasis: false,
                              ),
                              child: const Text('Run import wizard'),
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
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CrispyOverhaulTokens.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

Color _sourceStatusColor(String status) {
  switch (status) {
    case 'Healthy':
      return CrispyOverhaulTokens.semanticSuccess;
    case 'Degraded':
      return CrispyOverhaulTokens.semanticWarning;
    default:
      return CrispyOverhaulTokens.semanticDanger;
  }
}

class _SettingsSearchEmptyState extends StatelessWidget {
  const _SettingsSearchEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'No exact leaf found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              'Nothing in the Settings hierarchy matched "$query". Clear the search or try a leaf title, summary, or value.',
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

List<_SettingsSearchMatch> _findMatches(
  ShellContentSnapshot content,
  String query,
) {
  final String needle = query.toLowerCase();
  final List<_SettingsSearchMatch> matches = <_SettingsSearchMatch>[
    ..._settingsMatches(
      panel: SettingsPanel.general,
      items: content.generalSettings,
      query: needle,
    ),
    ..._settingsMatches(
      panel: SettingsPanel.playback,
      items: content.playbackSettings,
      query: needle,
    ),
    ..._settingsMatches(
      panel: SettingsPanel.appearance,
      items: content.appearanceSettings,
      query: needle,
    ),
    ..._settingsMatches(
      panel: SettingsPanel.system,
      items: content.systemSettings,
      query: needle,
    ),
    ..._sourceMatches(content.sourceHealthItems, needle),
  ];

  matches.sort(_compareSearchMatches);
  return matches;
}

List<_SettingsSearchMatch> _settingsMatches({
  required SettingsPanel panel,
  required List<SettingsItem> items,
  required String query,
}) {
  final List<_SettingsSearchMatch> matches = <_SettingsSearchMatch>[];
  for (int index = 0; index < items.length; index += 1) {
    final SettingsItem item = items[index];
    final int score = _scoreText(query, <String>[
      item.title,
      item.summary,
      item.value,
    ]);
    if (score > 0) {
      matches.add(
        _SettingsSearchMatch.settings(
          panel: panel,
          itemIndex: index,
          item: item,
          score: score,
        ),
      );
    }
  }
  return matches;
}

List<_SettingsSearchMatch> _sourceMatches(
  List<SourceHealthItem> sources,
  String query,
) {
  final List<_SettingsSearchMatch> matches = <_SettingsSearchMatch>[];
  for (int index = 0; index < sources.length; index += 1) {
    final SourceHealthItem source = sources[index];
    final int score = _scoreText(query, <String>[
      source.name,
      source.status,
      source.summary,
      source.sourceType,
      source.endpoint,
      source.lastSync,
      ...source.capabilities,
      source.primaryAction,
    ]);
    if (score > 0) {
      matches.add(
        _SettingsSearchMatch.source(
          sourceIndex: index,
          source: source,
          score: score,
        ),
      );
    }
  }
  return matches;
}

_SettingsSearchMatch? _matchForOpenedLeaf({
  required ShellContentSnapshot content,
  required SettingsPanel panel,
  required String? highlightedLeaf,
  required int selectedSourceIndex,
}) {
  if (highlightedLeaf == null) {
    return null;
  }
  if (panel == SettingsPanel.sources) {
    final int sourceIndex =
        highlightedLeaf.startsWith('source:')
            ? int.tryParse(highlightedLeaf.split(':').last) ??
                selectedSourceIndex
            : selectedSourceIndex;
    return _SettingsSearchMatch.source(
      sourceIndex: sourceIndex,
      source: content.sourceHealthItems[sourceIndex],
      score: 0,
    );
  }
  final List<SettingsItem> items = switch (panel) {
    SettingsPanel.general => content.generalSettings,
    SettingsPanel.playback => content.playbackSettings,
    SettingsPanel.appearance => content.appearanceSettings,
    SettingsPanel.system => content.systemSettings,
    SettingsPanel.sources => const <SettingsItem>[],
  };
  for (int index = 0; index < items.length; index += 1) {
    if (items[index].title == highlightedLeaf) {
      return _SettingsSearchMatch.settings(
        panel: panel,
        itemIndex: index,
        item: items[index],
        score: 0,
      );
    }
  }
  return null;
}

String _panelDescription(SettingsPanel panel) {
  return switch (panel) {
    SettingsPanel.general => 'Core app behavior and startup defaults.',
    SettingsPanel.playback => 'Playback safety and default behavior.',
    SettingsPanel.sources =>
      'Source onboarding, authentication, validation, and import stay inside Settings.',
    SettingsPanel.appearance => 'Display readability and shell density.',
    SettingsPanel.system => 'Diagnostics, storage, and environment.',
  };
}

int _scoreText(String query, List<String> values) {
  int best = 0;
  for (final String value in values) {
    final String lowerValue = value.toLowerCase();
    if (lowerValue == query) {
      return 100;
    }
    if (lowerValue.startsWith(query)) {
      best = best < 80 ? 80 : best;
    }
    if (lowerValue.contains(query)) {
      best = best < 60 ? 60 : best;
    }
  }
  return best;
}

int _compareSearchMatches(
  _SettingsSearchMatch left,
  _SettingsSearchMatch right,
) {
  final int scoreCompare = right.score.compareTo(left.score);
  if (scoreCompare != 0) {
    return scoreCompare;
  }
  final int panelCompare = left.panel.index.compareTo(right.panel.index);
  if (panelCompare != 0) {
    return panelCompare;
  }
  return (left.itemIndex ?? left.sourceIndex ?? 0).compareTo(
    right.itemIndex ?? right.sourceIndex ?? 0,
  );
}

class _SettingsSearchMatch {
  const _SettingsSearchMatch._({
    required this.panel,
    required this.score,
    required this.itemIndex,
    required this.sourceIndex,
    required this.item,
    required this.source,
  });

  factory _SettingsSearchMatch.settings({
    required SettingsPanel panel,
    required int itemIndex,
    required SettingsItem item,
    required int score,
  }) {
    return _SettingsSearchMatch._(
      panel: panel,
      score: score,
      itemIndex: itemIndex,
      sourceIndex: null,
      item: item,
      source: null,
    );
  }

  factory _SettingsSearchMatch.source({
    required int sourceIndex,
    required SourceHealthItem source,
    required int score,
  }) {
    return _SettingsSearchMatch._(
      panel: SettingsPanel.sources,
      score: score,
      itemIndex: null,
      sourceIndex: sourceIndex,
      item: null,
      source: source,
    );
  }

  final SettingsPanel panel;
  final int score;
  final int? itemIndex;
  final int? sourceIndex;
  final SettingsItem? item;
  final SourceHealthItem? source;

  String get displayLabel => item?.title ?? source?.name ?? panel.label;

  String get leafKey => item?.title ?? 'source:${sourceIndex ?? 0}';

  IconData get icon => switch (panel) {
    SettingsPanel.general => Icons.settings_suggest_outlined,
    SettingsPanel.playback => Icons.play_circle_outline,
    SettingsPanel.sources => Icons.hub_outlined,
    SettingsPanel.appearance => Icons.palette_outlined,
    SettingsPanel.system => Icons.developer_mode_outlined,
  };

  String supportingText(String query) {
    if (item != null) {
      if (item!.summary.toLowerCase().contains(query.toLowerCase())) {
        return item!.summary;
      }
      return item!.value;
    }
    return source?.summary ?? panel.label;
  }
}
