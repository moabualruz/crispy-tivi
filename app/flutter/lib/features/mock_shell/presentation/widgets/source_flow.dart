import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:flutter/material.dart';

class SourceFlow extends StatelessWidget {
  const SourceFlow({
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
    super.key,
  });

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
    final SourceHealthItem selectedSource = sources[selectedSourceIndex];
    final SourceWizardStepContent activeStep = wizardSteps.firstWhere(
      (SourceWizardStepContent item) => item.step == activeWizardStep,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Sources', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: CrispyOverhaulTokens.small),
        Text(
          'Source onboarding, authentication, validation, and import stay inside Settings. Existing sources open detail first; add source opens the wizard.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        DecoratedBox(
          decoration: CrispyShellRoles.infoPlateDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispyOverhaulTokens.medium,
              vertical: CrispyOverhaulTokens.small,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: CrispyOverhaulTokens.textSecondary,
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: Text(
                    'Settings-owned source management: list first, detail second, wizard only when needed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 312,
                child: _SourceListPane(
                  sources: sources,
                  selectedSourceIndex: selectedSourceIndex,
                  onSelectSource: onSelectSource,
                  onStartAddSource: onStartAddSource,
                ),
              ),
              const SizedBox(width: CrispyOverhaulTokens.medium),
              if (wizardActive) ...<Widget>[
                SizedBox(
                  width: 248,
                  child: _SourceWizardRail(
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
                        ? _SourceWizardPane(
                          step: activeStep,
                          onAdvance: onAdvanceWizard,
                          onRetreat: onRetreatWizard,
                        )
                        : _SourceDetailPane(
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

class _SourceListPane extends StatelessWidget {
  const _SourceListPane({
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
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
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
              child: ListView.separated(
                itemCount: sources.length,
                separatorBuilder:
                    (BuildContext context, int index) =>
                        const SizedBox(height: CrispyOverhaulTokens.small),
                itemBuilder: (BuildContext context, int index) {
                  final SourceHealthItem source = sources[index];
                  final bool selected = selectedSourceIndex == index;
                  return TextButton(
                    key: Key('source-item-${source.name}'),
                    onPressed: () => onSelectSource(index),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                source.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color:
                                      selected
                                          ? CrispyOverhaulTokens.navSelectedText
                                          : CrispyOverhaulTokens.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              source.status,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                selected
                                    ? CrispyOverhaulTokens.navSelectedText
                                    : CrispyOverhaulTokens.textSecondary,
                          ),
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

class _SourceWizardRail extends StatelessWidget {
  const _SourceWizardRail({
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
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
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

class _SourceDetailPane extends StatelessWidget {
  const _SourceDetailPane({
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
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: ListView(
          padding: EdgeInsets.zero,
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
                      color: _statusColor(source.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
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
            const SizedBox(height: CrispyOverhaulTokens.large),
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
                                  style: Theme.of(context).textTheme.bodyMedium,
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
            const SizedBox(height: CrispyOverhaulTokens.large),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CrispyOverhaulTokens.medium),
                    Row(
                      children: <Widget>[
                        TextButton(
                          key: const Key('sources-primary-action'),
                          onPressed:
                              source.status == 'Needs auth'
                                  ? onStartReconnect
                                  : onStartAddSource,
                          style: CrispyShellRoles.actionButtonStyle(
                            emphasis: true,
                          ),
                          child: Text(source.primaryAction),
                        ),
                        const SizedBox(width: CrispyOverhaulTokens.small),
                        TextButton(
                          key: const Key('sources-secondary-action'),
                          onPressed: onStartAddSource,
                          style: CrispyShellRoles.actionButtonStyle(
                            emphasis: false,
                          ),
                          child: const Text('Run import wizard'),
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
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Healthy':
        return CrispyOverhaulTokens.semanticSuccess;
      case 'Degraded':
        return CrispyOverhaulTokens.semanticWarning;
      default:
        return CrispyOverhaulTokens.semanticDanger;
    }
  }
}

class _SourceWizardPane extends StatelessWidget {
  const _SourceWizardPane({
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
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: CrispyShellRoles.iconPlateDecoration(),
                  child: Center(
                    child: Text(
                      '${step.step.index + 1}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
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
                        'Settings-owned source wizard lane',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CrispyOverhaulTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              step.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            for (final String fieldLabel in step.fieldLabels) ...<Widget>[
              _DetailField(label: fieldLabel, value: _mockValue(fieldLabel)),
              const SizedBox(height: CrispyOverhaulTokens.small),
            ],
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Text(
              'What this step covers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            for (final String helperLine in step.helperLines) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: CrispyOverhaulTokens.textMuted,
                    ),
                  ),
                  const SizedBox(width: CrispyOverhaulTokens.small),
                  Expanded(
                    child: Text(
                      helperLine,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CrispyOverhaulTokens.small),
            ],
            const SizedBox(height: CrispyOverhaulTokens.large),
            Row(
              children: <Widget>[
                TextButton(
                  key: const Key('source-wizard-back-button'),
                  onPressed: onRetreat,
                  style: CrispyShellRoles.actionButtonStyle(emphasis: false),
                  child: Text(step.secondaryAction),
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                TextButton(
                  key: const Key('source-wizard-next-button'),
                  onPressed: onAdvance,
                  style: CrispyShellRoles.actionButtonStyle(emphasis: true),
                  child: Text(step.primaryAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _mockValue(String fieldLabel) {
    switch (fieldLabel) {
      case 'Source type':
        return 'Xtream Codes';
      case 'Connection endpoint':
        return 'iptv.example.com / provider path';
      case 'Display name':
        return 'Living Room IPTV';
      case 'Username':
        return 'demo_user';
      case 'Password':
        return '••••••••';
      case 'Headers':
        return 'User-Agent, Referer';
      case 'Import scope':
        return 'Channels + Guide + Movies + Series';
      case 'Validation result':
        return 'Auth valid, streams reachable';
      default:
        return 'Configured';
    }
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.inputFieldDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.medium),
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
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
