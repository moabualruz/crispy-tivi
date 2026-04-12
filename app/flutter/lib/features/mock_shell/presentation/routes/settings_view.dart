import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/settings_rows.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/source_flow.dart';
import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    required this.panel,
    required this.content,
    required this.selectedSourceIndex,
    required this.sourceWizardActive,
    required this.sourceWizardStep,
    required this.onSelectSource,
    required this.onStartAddSource,
    required this.onStartReconnect,
    required this.onSelectWizardStep,
    required this.onAdvanceWizard,
    required this.onRetreatWizard,
    super.key,
  });

  final SettingsPanel panel;
  final MockShellContentSnapshot content;
  final int selectedSourceIndex;
  final bool sourceWizardActive;
  final SourceWizardStep sourceWizardStep;
  final ValueChanged<int> onSelectSource;
  final VoidCallback onStartAddSource;
  final VoidCallback onStartReconnect;
  final ValueChanged<SourceWizardStep> onSelectWizardStep;
  final VoidCallback onAdvanceWizard;
  final VoidCallback onRetreatWizard;

  @override
  Widget build(BuildContext context) {
    switch (panel) {
      case SettingsPanel.general:
        return _SettingsSectionView(
          title: 'General',
          description: 'Core app behavior and startup defaults.',
          child: SettingsRows(
            items: content.generalSettings,
            sectionLabel: 'General settings',
            sectionSummary:
                'Keep launch and recommendation behavior inside the utility lane.',
          ),
        );
      case SettingsPanel.playback:
        return _SettingsSectionView(
          title: 'Playback',
          description: 'Playback safety and default behavior.',
          child: SettingsRows(
            items: content.playbackSettings,
            sectionLabel: 'Playback settings',
            sectionSummary:
                'Playback defaults should be calm, explicit, and easy to unwind.',
          ),
        );
      case SettingsPanel.sources:
        return SourceFlow(
          sources: content.sourceHealthItems,
          selectedSourceIndex: selectedSourceIndex,
          wizardActive: sourceWizardActive,
          wizardSteps: content.sourceWizardSteps,
          activeWizardStep: sourceWizardStep,
          onSelectSource: onSelectSource,
          onStartAddSource: onStartAddSource,
          onStartReconnect: onStartReconnect,
          onSelectWizardStep: onSelectWizardStep,
          onAdvanceWizard: onAdvanceWizard,
          onRetreatWizard: onRetreatWizard,
        );
      case SettingsPanel.appearance:
        return _SettingsSectionView(
          title: 'Appearance',
          description: 'Display readability and shell density.',
          child: SettingsRows(
            items: content.appearanceSettings,
            sectionLabel: 'Appearance settings',
            sectionSummary:
                'Keep readability, density, and surface treatment in one place.',
          ),
        );
      case SettingsPanel.system:
        return _SettingsSectionView(
          title: 'System',
          description: 'Diagnostics, storage, and environment.',
          child: SettingsRows(
            items: content.systemSettings,
            sectionLabel: 'System settings',
            sectionSummary:
                'System controls stay grouped so diagnostics never feel detached.',
          ),
        );
    }
  }
}

class _SettingsSectionView extends StatelessWidget {
  const _SettingsSectionView({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: CrispyOverhaulTokens.medium,
                      vertical: CrispyOverhaulTokens.small,
                    ),
                    child: Text(
                      'Google TV-like utility hierarchy: icon, label, value, destination.',
                      style: TextStyle(
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
