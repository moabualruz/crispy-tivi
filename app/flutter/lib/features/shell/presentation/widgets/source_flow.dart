import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_view_model.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
import 'package:flutter/material.dart';

class SourceFlow extends StatelessWidget {
  const SourceFlow({
    required this.registry,
    required this.selectedSourceIndex,
    required this.wizardActive,
    required this.activeWizardStep,
    required this.onSelectSource,
    required this.onStartAddSource,
    required this.onStartReconnect,
    required this.onSelectWizardStep,
    required this.onAdvanceWizard,
    required this.onRetreatWizard,
    super.key,
  });

  final SourceProviderRegistry registry;
  final int selectedSourceIndex;
  final bool wizardActive;
  final SourceWizardStep activeWizardStep;
  final ValueChanged<int> onSelectSource;
  final VoidCallback onStartAddSource;
  final VoidCallback onStartReconnect;
  final ValueChanged<SourceWizardStep> onSelectWizardStep;
  final VoidCallback onAdvanceWizard;
  final VoidCallback onRetreatWizard;

  @override
  Widget build(BuildContext context) {
    if (registry.configuredProviders.isEmpty) {
      return _EmptyRegistryState(onStartAddSource: onStartAddSource);
    }

    final SourceProviderEntry selectedProvider = registry.configuredProviderAt(
      selectedSourceIndex,
    );
    final SourceWizardStepContent activeStep = registry.wizardStep(
      activeWizardStep,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Provider registry',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        Text(
          'Providers, health, auth, and import live inside Settings. Select a provider for detail or start the wizard only when needed.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 316,
                child: _ProviderListPane(
                  registry: registry,
                  selectedSourceIndex: selectedSourceIndex,
                  onSelectSource: onSelectSource,
                  onStartAddSource: onStartAddSource,
                ),
              ),
              const SizedBox(width: CrispyOverhaulTokens.medium),
              if (wizardActive) ...<Widget>[
                SizedBox(
                  width: 248,
                  child: _WizardRail(
                    steps: registry.wizardSteps,
                    activeStep: activeWizardStep,
                    onSelectStep: onSelectWizardStep,
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.medium),
              ],
              Expanded(
                child:
                    wizardActive
                        ? _WizardPane(
                          step: activeStep,
                          onAdvance: onAdvanceWizard,
                          onRetreat: onRetreatWizard,
                        )
                        : _ProviderDetailPane(
                          provider: selectedProvider,
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

class _ProviderListPane extends StatelessWidget {
  const _ProviderListPane({
    required this.registry,
    required this.selectedSourceIndex,
    required this.onSelectSource,
    required this.onStartAddSource,
  });

  final SourceProviderRegistry registry;
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
                    'Providers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              '${registry.configuredProviders.length} active providers',
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
              child: ListView.separated(
                itemCount: registry.configuredProviders.length,
                separatorBuilder:
                    (BuildContext context, int index) =>
                        const SizedBox(height: CrispyOverhaulTokens.small),
                itemBuilder: (BuildContext context, int index) {
                  final SourceProviderEntry provider = registry
                      .configuredProviderAt(index);
                  return _ProviderListItem(
                    provider: provider,
                    selected: index == selectedSourceIndex,
                    onSelect: () => onSelectSource(index),
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

class _ProviderListItem extends StatelessWidget {
  const _ProviderListItem({
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
                icon: _providerIcon(provider.providerKind),
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
                stateLabel: provider.healthState.label,
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
                stateLabel: provider.authState.label,
                state: provider.authState,
                selected: selected,
              ),
              _StateLabel(
                stateLabel: provider.importState.label,
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

class _WizardRail extends StatelessWidget {
  const _WizardRail({
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

class _WizardPane extends StatelessWidget {
  const _WizardPane({
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
              Wrap(
                spacing: CrispyOverhaulTokens.small,
                runSpacing: CrispyOverhaulTokens.small,
                children: <Widget>[
                  ShellControlButton(
                    controlKey: const Key('source-wizard-secondary-action'),
                    label: step.secondaryAction,
                    icon: CrispyShellIcons.settingsAction(step.secondaryAction),
                    onPressed: onRetreat,
                    controlRole: ShellControlRole.action,
                    presentation: ShellControlPresentation.iconAndText,
                  ),
                  ShellControlButton(
                    controlKey: const Key('source-wizard-primary-action'),
                    label: step.primaryAction,
                    icon: CrispyShellIcons.settingsAction(step.primaryAction),
                    onPressed: onAdvance,
                    controlRole: ShellControlRole.action,
                    presentation: ShellControlPresentation.iconAndText,
                    emphasis: true,
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

class _ProviderDetailPane extends StatelessWidget {
  const _ProviderDetailPane({
    required this.provider,
    required this.onStartReconnect,
    required this.onStartAddSource,
  });

  final SourceProviderEntry provider;
  final VoidCallback onStartReconnect;
  final VoidCallback onStartAddSource;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.insetPanelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
        child: SingleChildScrollView(
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
                          icon: _providerIcon(provider.providerKind),
                          role: ShellIconRole.status,
                          color: _stateColor(provider.healthState),
                        ),
                        const SizedBox(width: CrispyOverhaulTokens.compact),
                        Text(
                          provider.providerKind.label,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                            color: _stateColor(provider.healthState),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              _DetailField(
                label: 'Provider type',
                value: provider.providerKind.label,
              ),
              const SizedBox(height: CrispyOverhaulTokens.small),
              _DetailField(
                label: 'Source type',
                value: provider.sourceTypeLabel,
              ),
              const SizedBox(height: CrispyOverhaulTokens.small),
              _DetailField(label: 'Endpoint', value: provider.endpointLabel),
              const SizedBox(height: CrispyOverhaulTokens.small),
              _DetailField(label: 'Last sync', value: provider.lastSyncLabel),
              const SizedBox(height: CrispyOverhaulTokens.medium),
              Text('States', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CrispyOverhaulTokens.small),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StateCard(
                      label: 'Health',
                      stateLabel: provider.healthState.label,
                      icon: _stateIcon(provider.healthState),
                      color: _stateColor(provider.healthState),
                    ),
                  ),
                  const SizedBox(width: CrispyOverhaulTokens.small),
                  Expanded(
                    child: _StateCard(
                      label: 'Auth',
                      stateLabel: provider.authState.label,
                      icon: _stateIcon(provider.authState),
                      color: _stateColor(provider.authState),
                    ),
                  ),
                  const SizedBox(width: CrispyOverhaulTokens.small),
                  Expanded(
                    child: _StateCard(
                      label: 'Import',
                      stateLabel: provider.importState.label,
                      icon: _stateIcon(provider.importState),
                      color: _stateColor(provider.importState),
                    ),
                  ),
                ],
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
                        'Reconnect stays inside Settings and import remains an explicit step.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.medium),
                      Wrap(
                        spacing: CrispyOverhaulTokens.small,
                        runSpacing: CrispyOverhaulTokens.small,
                        children: <Widget>[
                          ShellControlButton(
                            controlKey: const Key('sources-primary-action'),
                            label: provider.primaryActionLabel,
                            icon: CrispyShellIcons.settingsAction(
                              provider.primaryActionLabel,
                            ),
                            onPressed:
                                provider.authState == SourceAuthState.needsAuth
                                    ? onStartReconnect
                                    : onStartAddSource,
                            controlRole: ShellControlRole.action,
                            presentation: ShellControlPresentation.iconAndText,
                            emphasis: true,
                          ),
                          ShellControlButton(
                            controlKey: const Key('sources-secondary-action'),
                            label: provider.secondaryActionLabel,
                            icon: Icons.playlist_add_outlined,
                            onPressed: onStartAddSource,
                            controlRole: ShellControlRole.action,
                            presentation: ShellControlPresentation.iconAndText,
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
    required this.stateLabel,
    required this.state,
    required this.selected,
  });

  final String stateLabel;
  final Object state;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = _stateColor(state);
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
              stateLabel,
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

class _EmptyRegistryState extends StatelessWidget {
  const _EmptyRegistryState({required this.onStartAddSource});

  final VoidCallback onStartAddSource;

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
              'Provider registry',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              'No providers are registered yet. Start the provider wizard to add one.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            ShellControlButton(
              controlKey: const Key('sources-add-button'),
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

IconData _providerIcon(SourceProviderKind kind) {
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

Color _stateColor(Object state) {
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
