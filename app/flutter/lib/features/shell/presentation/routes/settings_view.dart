import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/settings_rows.dart';
import 'package:crispy_tivi/features/shell/presentation/view_state/source_provider_registry.dart';
import 'package:crispy_tivi/features/shell/presentation/view_state/source_wizard_form.dart';
import 'package:crispy_tivi/features/shell/presentation/view_state/source_wizard_form_projection.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_view_model.dart';
import 'package:flutter/material.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.panel,
    required this.generalSettings,
    required this.playbackSettings,
    required this.appearanceSettings,
    required this.systemSettings,
    required this.diagnosticsRuntime,
    required this.sourceRegistry,
    required this.selectedSourceIndex,
    required this.selectedProviderType,
    required this.sourceWizardActive,
    required this.sourceWizardStep,
    required this.sourceWizardFieldValues,
    required this.searchQuery,
    required this.highlightedLeaf,
    required this.onUpdateSearchQuery,
    required this.onClearSearch,
    required this.onOpenSettingsLeaf,
    required this.onSelectSource,
    required this.onSelectProviderType,
    required this.onStartAddSource,
    required this.onStartEditSource,
    required this.onStartReconnect,
    required this.onStartImportSource,
    required this.onSelectWizardStep,
    required this.onUpdateWizardField,
    required this.onAdvanceWizard,
    required this.onRetreatWizard,
    super.key,
  });

  final SettingsPanel panel;
  final List<SettingsItem> generalSettings;
  final List<SettingsItem> playbackSettings;
  final List<SettingsItem> appearanceSettings;
  final List<SettingsItem> systemSettings;
  final DiagnosticsRuntimeSnapshot diagnosticsRuntime;
  final SourceProviderRegistry sourceRegistry;
  final int selectedSourceIndex;
  final SourceProviderKind selectedProviderType;
  final bool sourceWizardActive;
  final SourceWizardStep sourceWizardStep;
  final Map<String, String> sourceWizardFieldValues;
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
  final ValueChanged<SourceProviderKind> onSelectProviderType;
  final VoidCallback onStartAddSource;
  final VoidCallback onStartEditSource;
  final VoidCallback onStartReconnect;
  final VoidCallback onStartImportSource;
  final ValueChanged<SourceWizardStep> onSelectWizardStep;
  final void Function(String fieldLabel, String value) onUpdateWizardField;
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
            : _findMatches(
              generalSettings: widget.generalSettings,
              playbackSettings: widget.playbackSettings,
              appearanceSettings: widget.appearanceSettings,
              systemSettings: widget.systemSettings,
              sourceRegistry: widget.sourceRegistry,
              query: query,
            );

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
      generalSettings: widget.generalSettings,
      playbackSettings: widget.playbackSettings,
      appearanceSettings: widget.appearanceSettings,
      systemSettings: widget.systemSettings,
      sourceRegistry: widget.sourceRegistry,
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
          panel: panel,
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: SettingsRows(
            items: widget.generalSettings,
            sectionLabel: 'General settings',
            sectionSummary:
                'Keep launch and recommendation behavior inside the utility lane.',
            highlightedItemIndex: highlightedItemIndex,
          ),
        );
      case SettingsPanel.playback:
        return _SettingsSectionView(
          panel: panel,
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: SettingsRows(
            items: widget.playbackSettings,
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
          sourceRegistry: widget.sourceRegistry,
          selectedSourceIndex: forcedSourceIndex ?? widget.selectedSourceIndex,
          selectedProviderType: widget.selectedProviderType,
          wizardActive:
              widget.sourceWizardActive && highlightedItemIndex == null,
          wizardSteps: widget.sourceRegistry.wizardSteps,
          activeWizardStep: widget.sourceWizardStep,
          sourceWizardFieldValues: widget.sourceWizardFieldValues,
          onSelectSource: widget.onSelectSource,
          onSelectProviderType: widget.onSelectProviderType,
          onStartAddSource: widget.onStartAddSource,
          onStartEditSource: widget.onStartEditSource,
          onStartReconnect: widget.onStartReconnect,
          onStartImportSource: widget.onStartImportSource,
          onSelectWizardStep: widget.onSelectWizardStep,
          onUpdateWizardField: widget.onUpdateWizardField,
          onAdvanceWizard: widget.onAdvanceWizard,
          onRetreatWizard: widget.onRetreatWizard,
        );
      case SettingsPanel.appearance:
        return _SettingsSectionView(
          panel: panel,
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: SettingsRows(
            items: widget.appearanceSettings,
            sectionLabel: 'Appearance settings',
            sectionSummary:
                'Keep readability, density, and surface treatment in one place.',
            highlightedItemIndex: highlightedItemIndex,
          ),
        );
      case SettingsPanel.system:
        return _SettingsSectionView(
          panel: panel,
          title: title,
          description: description,
          matchDescription: matchDescription,
          child: _SystemSettingsPanel(
            items: widget.systemSettings,
            diagnostics: widget.diagnosticsRuntime,
            highlightedItemIndex: highlightedItemIndex,
          ),
        );
    }
  }
}

class _SystemSettingsPanel extends StatelessWidget {
  const _SystemSettingsPanel({
    required this.items,
    required this.diagnostics,
    this.highlightedItemIndex,
  });

  final List<SettingsItem> items;
  final DiagnosticsRuntimeSnapshot diagnostics;
  final int? highlightedItemIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsRows(
          items: items,
          sectionLabel: 'System settings',
          sectionSummary:
              'System controls stay grouped so diagnostics never feel detached.',
          highlightedItemIndex: highlightedItemIndex,
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
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
                    const ShellIconPlate(
                      icon: Icons.health_and_safety_outlined,
                      role: ShellIconRole.panel,
                    ),
                    const SizedBox(width: CrispyOverhaulTokens.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Diagnostics',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: CrispyOverhaulTokens.compact),
                          Text(
                            diagnostics.validationSummary,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: CrispyOverhaulTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CrispyOverhaulTokens.medium),
                Wrap(
                  spacing: CrispyOverhaulTokens.small,
                  runSpacing: CrispyOverhaulTokens.small,
                  children: <Widget>[
                    _DiagnosticsBadge(
                      label:
                          diagnostics.ffprobeAvailable
                              ? 'ffprobe ready'
                              : 'ffprobe unavailable',
                    ),
                    _DiagnosticsBadge(
                      label:
                          diagnostics.ffmpegAvailable
                              ? 'ffmpeg ready'
                              : 'ffmpeg unavailable',
                    ),
                  ],
                ),
                const SizedBox(height: CrispyOverhaulTokens.large),
                ...diagnostics.reports.map(
                  (DiagnosticsReport report) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: CrispyOverhaulTokens.medium,
                    ),
                    child: _DiagnosticsCard(report: report),
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

class _DiagnosticsBadge extends StatelessWidget {
  const _DiagnosticsBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.medium,
          vertical: CrispyOverhaulTokens.small,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.report});

  final DiagnosticsReport report;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              report.streamTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              '${report.sourceName} · ${report.category} · ${report.resolutionLabel}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            ...report.detailLines.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(
                  bottom: CrispyOverhaulTokens.compact,
                ),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
                ),
              ),
            ),
            if (report.mismatchWarnings.isNotEmpty) ...<Widget>[
              const SizedBox(height: CrispyOverhaulTokens.compact),
              Text(
                report.mismatchWarnings.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CrispyOverhaulTokens.semanticWarning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
                const ShellIconPlate(
                  icon: Icons.search,
                  role: ShellIconRole.panel,
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
                  ShellControlButton(
                    label: 'Clear',
                    semanticsLabel: 'Clear search',
                    icon: Icons.close_rounded,
                    onPressed: onClear,
                    controlRole: ShellControlRole.action,
                    presentation: ShellControlPresentation.iconOnly,
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
              'Search only this settings hierarchy.',
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
            Row(
              children: <Widget>[
                const ShellIconPlate(
                  icon: Icons.search,
                  role: ShellIconRole.row,
                ),
                const SizedBox(width: CrispyOverhaulTokens.medium),
                Text(
                  'Search results',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
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
                  return ShellControlSurface(
                    controlKey: Key('settings-search-hit-$index'),
                    onPressed:
                        () => onActivate(
                          panel: match.panel,
                          leafLabel: match.leafKey,
                          sourceIndex: match.sourceIndex,
                        ),
                    controlRole: ShellControlRole.selector,
                    semanticsLabel: match.displayLabel,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ShellIconPlate(
                          icon: match.icon,
                          role: ShellIconRole.row,
                        ),
                        const SizedBox(width: CrispyOverhaulTokens.medium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                match.displayLabel,
                                style: Theme.of(context).textTheme.titleMedium,
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
                        const ShellIconGraphic(
                          icon: Icons.chevron_right,
                          role: ShellIconRole.compact,
                          color: CrispyOverhaulTokens.textMuted,
                        ),
                      ],
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
    required this.panel,
    required this.title,
    required this.description,
    required this.matchDescription,
    required this.child,
  });

  final SettingsPanel panel;
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
                    ShellIconPlate(
                      icon: CrispyShellIcons.settingsPanel(panel),
                      role: ShellIconRole.panel,
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
    required this.sourceRegistry,
    required this.selectedSourceIndex,
    required this.selectedProviderType,
    required this.wizardActive,
    required this.wizardSteps,
    required this.activeWizardStep,
    required this.sourceWizardFieldValues,
    required this.onSelectSource,
    required this.onSelectProviderType,
    required this.onStartAddSource,
    required this.onStartEditSource,
    required this.onStartReconnect,
    required this.onStartImportSource,
    required this.onSelectWizardStep,
    required this.onUpdateWizardField,
    required this.onAdvanceWizard,
    required this.onRetreatWizard,
  });

  final String title;
  final String description;
  final String matchDescription;
  final SourceProviderRegistry sourceRegistry;
  final int selectedSourceIndex;
  final SourceProviderKind selectedProviderType;
  final bool wizardActive;
  final List<SourceWizardStepContent> wizardSteps;
  final SourceWizardStep activeWizardStep;
  final Map<String, String> sourceWizardFieldValues;
  final ValueChanged<int> onSelectSource;
  final ValueChanged<SourceProviderKind> onSelectProviderType;
  final VoidCallback onStartAddSource;
  final VoidCallback onStartEditSource;
  final VoidCallback onStartReconnect;
  final VoidCallback onStartImportSource;
  final ValueChanged<SourceWizardStep> onSelectWizardStep;
  final void Function(String fieldLabel, String value) onUpdateWizardField;
  final VoidCallback onAdvanceWizard;
  final VoidCallback onRetreatWizard;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasProviderCatalog =
        sourceRegistry.providerTypes.isNotEmpty && wizardSteps.isNotEmpty;
    final SourceProviderEntry? selectedProvider =
        sourceRegistry.configuredProviders.isEmpty
            ? null
            : sourceRegistry.configuredProviderAt(selectedSourceIndex);
    final SourceProviderEntry? selectedProviderTypeEntry =
        hasProviderCatalog
            ? sourceRegistry.providerType(selectedProviderType)
            : null;
    final SourceWizardStepContent? activeStep =
        hasProviderCatalog
            ? wizardSteps.firstWhere(
              (SourceWizardStepContent item) => item.step == activeWizardStep,
            )
            : null;

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
                  sourceRegistry: sourceRegistry,
                  selectedSourceIndex: selectedSourceIndex,
                  onSelectSource: onSelectSource,
                  onStartAddSource: onStartAddSource,
                ),
              ),
              const SizedBox(width: CrispyOverhaulTokens.medium),
              if (wizardActive && hasProviderCatalog) ...<Widget>[
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
                    wizardActive && hasProviderCatalog
                        ? _SettingsWizardPane(
                          step: activeStep!,
                          providerTypes: sourceRegistry.providerTypes,
                          selectedProviderType: selectedProviderType,
                          fieldValues: sourceWizardFieldValues,
                          onSelectProviderType: onSelectProviderType,
                          onUpdateField: onUpdateWizardField,
                          onAdvance: onAdvanceWizard,
                          onRetreat: onRetreatWizard,
                        )
                        : wizardActive
                        ? const _SettingsSourceCatalogEmpty()
                        : selectedProvider == null
                        ? _SettingsEmptySourceDetailPane(
                          provider: selectedProviderTypeEntry,
                          onStartAddSource: onStartAddSource,
                        )
                        : _SettingsSourceDetailPane(
                          provider: selectedProvider,
                          onStartReconnect: onStartReconnect,
                          onStartEditSource: onStartEditSource,
                          onStartImportSource: onStartImportSource,
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
    required this.sourceRegistry,
    required this.selectedSourceIndex,
    required this.onSelectSource,
    required this.onStartAddSource,
  });

  final SourceProviderRegistry sourceRegistry;
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
            Row(
              children: <Widget>[
                ShellIconPlate(
                  icon: CrispyShellIcons.settingsPanel(SettingsPanel.sources),
                  role: ShellIconRole.row,
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: Text(
                    'Provider registry',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              '${sourceRegistry.configuredProviders.length} active providers',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            ShellControlButton(
              controlKey: const Key('sources-add-button'),
              label: 'Add provider',
              icon: Icons.add_link_outlined,
              onPressed: onStartAddSource,
              controlRole: ShellControlRole.action,
              presentation: ShellControlPresentation.iconAndText,
              emphasis: true,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (
                    int index = 0;
                    index < sourceRegistry.configuredProviders.length;
                    index += 1
                  ) ...<Widget>[
                    _SettingsSourceListItem(
                      provider: sourceRegistry.configuredProviderAt(index),
                      selected: selectedSourceIndex == index,
                      onSelect: () => onSelectSource(index),
                    ),
                    if (index < sourceRegistry.configuredProviders.length - 1)
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
    required this.provider,
    required this.selected,
    required this.onSelect,
  });

  final SourceProviderEntry provider;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return ShellControlSurface(
      controlKey: Key('source-item-${provider.name}'),
      onPressed: onSelect,
      controlRole: ShellControlRole.selector,
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ShellIconPlate(
                icon: _providerKindIcon(provider.providerKind),
                role: ShellIconRole.status,
                color:
                    selected
                        ? CrispyOverhaulTokens.navSelectedText
                        : CrispyOverhaulTokens.textSecondary,
              ),
              const SizedBox(width: CrispyOverhaulTokens.small),
              Expanded(
                child: Text(
                  provider.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        selected
                            ? CrispyOverhaulTokens.navSelectedText
                            : CrispyOverhaulTokens.textPrimary,
                  ),
                ),
              ),
              _StateLabel(
                label: provider.healthState.label,
                state: provider.healthState,
                selected: selected,
              ),
            ],
          ),
          const SizedBox(height: CrispyOverhaulTokens.compact),
          Text(
            provider.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  selected
                      ? CrispyOverhaulTokens.navSelectedText
                      : CrispyOverhaulTokens.textSecondary,
            ),
          ),
          const SizedBox(height: CrispyOverhaulTokens.small),
          Wrap(
            spacing: CrispyOverhaulTokens.small,
            runSpacing: CrispyOverhaulTokens.small,
            children: <Widget>[
              _StateLabel(
                label: provider.authState.label,
                state: provider.authState,
                selected: selected,
              ),
              _StateLabel(
                label: provider.importState.label,
                state: provider.importState,
                selected: selected,
              ),
            ],
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
                  return ShellControlSurface(
                    controlKey: Key('source-wizard-step-${step.step.label}'),
                    onPressed: () => onSelectStep(step.step),
                    controlRole: ShellControlRole.selector,
                    selected: selected,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
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
    required this.providerTypes,
    required this.selectedProviderType,
    required this.fieldValues,
    required this.onSelectProviderType,
    required this.onUpdateField,
    required this.onAdvance,
    required this.onRetreat,
  });

  final SourceWizardStepContent step;
  final List<SourceProviderEntry> providerTypes;
  final SourceProviderKind selectedProviderType;
  final Map<String, String> fieldValues;
  final ValueChanged<SourceProviderKind> onSelectProviderType;
  final void Function(String fieldLabel, String value) onUpdateField;
  final VoidCallback onAdvance;
  final VoidCallback onRetreat;

  @override
  Widget build(BuildContext context) {
    final List<SourceWizardFieldSpec> fields = buildSourceWizardFieldSpecs(
      providerTypes: providerTypes,
      selectedProviderKind: selectedProviderType,
      step: step.step,
      values: fieldValues,
    );
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
                  ShellIconPlate(
                    icon: CrispyShellIcons.settingsPanel(SettingsPanel.sources),
                    role: ShellIconRole.row,
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
                      for (final SourceWizardFieldSpec field
                          in fields) ...<Widget>[
                        _WizardField(
                          field: field,
                          initialValue: fieldValues[field.key] ?? '',
                          onChanged: (String value) {
                            onUpdateField(field.key, value);
                          },
                          onSelectProviderType: onSelectProviderType,
                          selectedProviderType: selectedProviderType,
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
              Wrap(
                spacing: CrispyOverhaulTokens.small,
                runSpacing: CrispyOverhaulTokens.small,
                children: <Widget>[
                  ShellControlButton(
                    controlKey: const Key('source-wizard-primary-action'),
                    label: step.primaryAction,
                    icon: CrispyShellIcons.settingsAction(step.primaryAction),
                    onPressed: onAdvance,
                    controlRole: ShellControlRole.action,
                    presentation: ShellControlPresentation.iconAndText,
                    emphasis: true,
                  ),
                  ShellControlButton(
                    controlKey: const Key('source-wizard-secondary-action'),
                    label: step.secondaryAction,
                    icon: CrispyShellIcons.settingsAction(step.secondaryAction),
                    onPressed: onRetreat,
                    controlRole: ShellControlRole.action,
                    presentation: ShellControlPresentation.iconAndText,
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

class _WizardField extends StatefulWidget {
  const _WizardField({
    required this.field,
    required this.initialValue,
    required this.onChanged,
    required this.onSelectProviderType,
    required this.selectedProviderType,
  });

  final SourceWizardFieldSpec field;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<SourceProviderKind> onSelectProviderType;
  final SourceProviderKind selectedProviderType;

  @override
  State<_WizardField> createState() => _WizardFieldState();
}

class _WizardFieldState extends State<_WizardField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void didUpdateWidget(covariant _WizardField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: CrispyOverhaulTokens.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.field.label, style: labelStyle),
        const SizedBox(height: CrispyOverhaulTokens.compact),
        switch (widget.field.kind) {
          SourceWizardFieldKind.choice => DropdownButtonFormField<String>(
            key: Key('source-wizard-field-${widget.field.key}'),
            initialValue:
                widget.field.key == 'source_type'
                    ? widget.selectedProviderType.name
                    : (widget.initialValue.isEmpty
                        ? null
                        : widget.initialValue),
            items: widget.field.options
                .map(
                  (SourceWizardFieldOption option) => DropdownMenuItem<String>(
                    value: option.value,
                    child: Text(option.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              if (widget.field.key == 'source_type') {
                widget.onSelectProviderType(
                  SourceProviderKind.values.firstWhere(
                    (SourceProviderKind kind) => kind.name == value,
                  ),
                );
              }
              widget.onChanged(value);
            },
            decoration: InputDecoration(hintText: widget.field.placeholder),
          ),
          SourceWizardFieldKind.readonly => DecoratedBox(
            decoration: CrispyShellRoles.inputFieldDecoration(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispyOverhaulTokens.large,
                vertical: CrispyOverhaulTokens.medium,
              ),
              child: Text(
                widget.field.readOnlyValue ?? 'Not available yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: CrispyOverhaulTokens.textSecondary,
                ),
              ),
            ),
          ),
          SourceWizardFieldKind.multiline => TextField(
            key: Key('source-wizard-field-${widget.field.key}'),
            controller: _controller,
            onChanged: widget.onChanged,
            maxLines: 3,
            decoration: InputDecoration(hintText: widget.field.placeholder),
          ),
          _ => TextField(
            key: Key('source-wizard-field-${widget.field.key}'),
            controller: _controller,
            onChanged: widget.onChanged,
            obscureText: widget.field.kind == SourceWizardFieldKind.password,
            keyboardType:
                widget.field.kind == SourceWizardFieldKind.url
                    ? TextInputType.url
                    : TextInputType.text,
            decoration: InputDecoration(hintText: widget.field.placeholder),
          ),
        },
      ],
    );
  }
}

class _SettingsEmptySourceDetailPane extends StatelessWidget {
  const _SettingsEmptySourceDetailPane({
    required this.provider,
    required this.onStartAddSource,
  });

  final SourceProviderEntry? provider;
  final VoidCallback onStartAddSource;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'No providers configured yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              provider == null
                  ? 'The provider catalog is still loading. Add provider becomes available as soon as catalog metadata is present.'
                  : 'Start with ${provider!.name}. The wizard now uses the retained provider catalog even before any real source exists.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            ShellControlButton(
              controlKey: const Key('sources-empty-add-button'),
              label: 'Add provider',
              icon: Icons.add_link_outlined,
              onPressed: onStartAddSource,
              controlRole: ShellControlRole.action,
              presentation: ShellControlPresentation.iconAndText,
              emphasis: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSourceCatalogEmpty extends StatelessWidget {
  const _SettingsSourceCatalogEmpty();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Provider catalog unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              'Source setup cannot continue until provider catalog metadata is available on the active runtime path.',
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

class _SettingsSourceDetailPane extends StatelessWidget {
  const _SettingsSourceDetailPane({
    required this.provider,
    required this.onStartReconnect,
    required this.onStartEditSource,
    required this.onStartImportSource,
  });

  final SourceProviderEntry provider;
  final VoidCallback onStartReconnect;
  final VoidCallback onStartEditSource;
  final VoidCallback onStartImportSource;

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
                          provider.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.compact),
                        Text(
                          provider.summary,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ShellIconGraphic(
                          icon: _providerKindIcon(provider.providerKind),
                          role: ShellIconRole.status,
                          color: _sourceStateColor(provider.healthState),
                        ),
                        const SizedBox(width: CrispyOverhaulTokens.compact),
                        Text(
                          provider.providerKind.label,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                            color: _sourceStateColor(provider.healthState),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              _RegistryStateGrid(provider: provider),
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
                    children: provider.capabilities
                        .map(
                          (SourceCapabilityDescriptor capability) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: CrispyOverhaulTokens.small,
                            ),
                            child: Row(
                              children: <Widget>[
                                ShellIconGraphic(
                                  icon: _capabilityIcon(capability.kind),
                                  role: ShellIconRole.row,
                                  color: CrispyOverhaulTokens.textMuted,
                                ),
                                const SizedBox(
                                  width: CrispyOverhaulTokens.small,
                                ),
                                Expanded(
                                  child: Text(
                                    capability.kind.label,
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
                        'Provider actions',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      Text(
                        'Edit, reconnect, and import stay inside the same Settings-owned runtime lane.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.medium),
                      Row(
                        children: <Widget>[
                          SizedBox(
                            key: const Key('sources-primary-action'),
                            child: ShellControlButton(
                              label: provider.primaryActionLabel,
                              icon: CrispyShellIcons.settingsAction(
                                provider.primaryActionLabel,
                              ),
                              onPressed:
                                  provider.authState ==
                                          SourceAuthState.needsAuth
                                      ? onStartReconnect
                                      : onStartEditSource,
                              controlRole: ShellControlRole.action,
                              presentation:
                                  ShellControlPresentation.iconAndText,
                              emphasis: true,
                            ),
                          ),
                          const SizedBox(width: CrispyOverhaulTokens.small),
                          SizedBox(
                            key: const Key('sources-secondary-action'),
                            child: ShellControlButton(
                              label: provider.secondaryActionLabel,
                              icon: Icons.playlist_add_outlined,
                              onPressed: onStartImportSource,
                              controlRole: ShellControlRole.action,
                              presentation:
                                  ShellControlPresentation.iconAndText,
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

class _RegistryStateGrid extends StatelessWidget {
  const _RegistryStateGrid({required this.provider});

  final SourceProviderEntry provider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: Column(
          children: <Widget>[
            _DetailField(
              label: 'Provider type',
              value: provider.providerKind.label,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            _DetailField(label: 'Source type', value: provider.sourceTypeLabel),
            const SizedBox(height: CrispyOverhaulTokens.small),
            _DetailField(label: 'Endpoint', value: provider.endpointLabel),
            const SizedBox(height: CrispyOverhaulTokens.small),
            _DetailField(label: 'Last sync', value: provider.lastSyncLabel),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StateCard(
                    label: 'Health',
                    stateLabel: provider.healthState.label,
                    icon: _stateIcon(provider.healthState),
                    color: _sourceStateColor(provider.healthState),
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: _StateCard(
                    label: 'Auth',
                    stateLabel: provider.authState.label,
                    icon: _stateIcon(provider.authState),
                    color: _sourceStateColor(provider.authState),
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: _StateCard(
                    label: 'Import',
                    stateLabel: provider.importState.label,
                    icon: _stateIcon(provider.importState),
                    color: _sourceStateColor(provider.importState),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.label,
    required this.stateLabel,
    required this.icon,
    required this.color,
  });

  final String label;
  final String stateLabel;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.small),
        child: Row(
          children: <Widget>[
            ShellIconGraphic(icon: icon, role: ShellIconRole.row, color: color),
            const SizedBox(width: CrispyOverhaulTokens.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CrispyOverhaulTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.compact),
                  Text(
                    stateLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateLabel extends StatelessWidget {
  const _StateLabel({
    required this.label,
    required this.state,
    required this.selected,
  });

  final String label;
  final Object state;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = _sourceStateColor(state);
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.small,
          vertical: CrispyOverhaulTokens.compact,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ShellIconGraphic(
              icon: _stateIcon(state),
              role: ShellIconRole.badge,
              color: selected ? CrispyOverhaulTokens.navSelectedText : color,
            ),
            const SizedBox(width: CrispyOverhaulTokens.compact),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? CrispyOverhaulTokens.navSelectedText : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _providerKindIcon(SourceProviderKind kind) {
  return switch (kind) {
    SourceProviderKind.m3uUrl => Icons.link_outlined,
    SourceProviderKind.localM3u => Icons.folder_open_outlined,
    SourceProviderKind.xtream => Icons.hub_outlined,
    SourceProviderKind.stalker => Icons.router_outlined,
  };
}

IconData _stateIcon(Object state) {
  return switch (state) {
    SourceHealthState.healthy => Icons.check_circle,
    SourceHealthState.degraded => Icons.warning_amber_outlined,
    SourceHealthState.needsAuth => Icons.lock_outline,
    SourceHealthState.unknown => Icons.help_outline,
    SourceAuthState.connected => Icons.verified_outlined,
    SourceAuthState.reconnecting => Icons.sync_outlined,
    SourceAuthState.needsAuth => Icons.lock_outline,
    SourceAuthState.unknown => Icons.help_outline,
    SourceImportState.ready => Icons.download_done_outlined,
    SourceImportState.pending => Icons.downloading_outlined,
    SourceImportState.blocked => Icons.block_outlined,
    SourceImportState.unknown => Icons.help_outline,
    _ => Icons.circle_outlined,
  };
}

Color _sourceStateColor(Object state) {
  return switch (state) {
    SourceHealthState.healthy => CrispyOverhaulTokens.semanticSuccess,
    SourceHealthState.degraded => CrispyOverhaulTokens.semanticWarning,
    SourceHealthState.needsAuth => CrispyOverhaulTokens.semanticDanger,
    SourceHealthState.unknown => CrispyOverhaulTokens.textSecondary,
    SourceAuthState.connected => CrispyOverhaulTokens.semanticSuccess,
    SourceAuthState.reconnecting => CrispyOverhaulTokens.semanticWarning,
    SourceAuthState.needsAuth => CrispyOverhaulTokens.semanticDanger,
    SourceAuthState.unknown => CrispyOverhaulTokens.textSecondary,
    SourceImportState.ready => CrispyOverhaulTokens.semanticSuccess,
    SourceImportState.pending => CrispyOverhaulTokens.semanticWarning,
    SourceImportState.blocked => CrispyOverhaulTokens.semanticDanger,
    SourceImportState.unknown => CrispyOverhaulTokens.textSecondary,
    _ => CrispyOverhaulTokens.textSecondary,
  };
}

IconData _capabilityIcon(SourceCapabilityKind kind) {
  return switch (kind) {
    SourceCapabilityKind.liveTv => Icons.live_tv_outlined,
    SourceCapabilityKind.guide => Icons.view_timeline_outlined,
    SourceCapabilityKind.catchup => Icons.history_outlined,
    SourceCapabilityKind.archive => Icons.inventory_2_outlined,
    SourceCapabilityKind.movies => Icons.local_movies_outlined,
    SourceCapabilityKind.series => Icons.tv_outlined,
    SourceCapabilityKind.other => Icons.label_outline,
  };
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

List<_SettingsSearchMatch> _findMatches({
  required List<SettingsItem> generalSettings,
  required List<SettingsItem> playbackSettings,
  required List<SettingsItem> appearanceSettings,
  required List<SettingsItem> systemSettings,
  required SourceProviderRegistry sourceRegistry,
  required String query,
}) {
  final String needle = query.toLowerCase();
  final List<_SettingsSearchMatch> matches = <_SettingsSearchMatch>[
    ..._settingsMatches(
      panel: SettingsPanel.general,
      items: generalSettings,
      query: needle,
    ),
    ..._settingsMatches(
      panel: SettingsPanel.playback,
      items: playbackSettings,
      query: needle,
    ),
    ..._settingsMatches(
      panel: SettingsPanel.appearance,
      items: appearanceSettings,
      query: needle,
    ),
    ..._settingsMatches(
      panel: SettingsPanel.system,
      items: systemSettings,
      query: needle,
    ),
    ..._sourceMatches(sourceRegistry.configuredProviders, needle),
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
  List<SourceProviderEntry> providers,
  String query,
) {
  final List<_SettingsSearchMatch> matches = <_SettingsSearchMatch>[];
  for (int index = 0; index < providers.length; index += 1) {
    final SourceProviderEntry provider = providers[index];
    final int score = _scoreText(query, <String>[
      provider.name,
      provider.summary,
      provider.providerKind.label,
      provider.healthState.label,
      provider.authState.label,
      provider.importState.label,
      provider.sourceTypeLabel,
      provider.endpointLabel,
      provider.lastSyncLabel,
      ...provider.capabilities.map(
        (SourceCapabilityDescriptor capability) => capability.kind.label,
      ),
      provider.primaryActionLabel,
    ]);
    if (score > 0) {
      matches.add(
        _SettingsSearchMatch.source(
          sourceIndex: index,
          source: provider,
          score: score,
        ),
      );
    }
  }
  return matches;
}

_SettingsSearchMatch? _matchForOpenedLeaf({
  required List<SettingsItem> generalSettings,
  required List<SettingsItem> playbackSettings,
  required List<SettingsItem> appearanceSettings,
  required List<SettingsItem> systemSettings,
  required SourceProviderRegistry sourceRegistry,
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
      source: sourceRegistry.configuredProviderAt(sourceIndex),
      score: 0,
    );
  }
  final List<SettingsItem> items = switch (panel) {
    SettingsPanel.general => generalSettings,
    SettingsPanel.playback => playbackSettings,
    SettingsPanel.appearance => appearanceSettings,
    SettingsPanel.system => systemSettings,
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
    required SourceProviderEntry source,
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
  final SourceProviderEntry? source;

  String get displayLabel => item?.title ?? source?.name ?? panel.label;

  String get leafKey => item?.title ?? 'source:${sourceIndex ?? 0}';

  IconData get icon => CrispyShellIcons.settingsPanel(panel);

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
