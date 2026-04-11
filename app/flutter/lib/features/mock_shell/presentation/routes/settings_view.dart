import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/data/mock_shell_catalog.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/settings_rows.dart';
import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({required this.panel, super.key});

  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    switch (panel) {
      case SettingsPanel.general:
        return const _SettingsSectionView(
          title: 'General',
          description: 'Core app behavior and startup defaults.',
          child: SettingsRows(items: generalSettings),
        );
      case SettingsPanel.playback:
        return const _SettingsSectionView(
          title: 'Playback',
          description: 'Playback safety and default behavior.',
          child: SettingsRows(items: playbackSettings),
        );
      case SettingsPanel.sources:
        return const _SourcesSectionView();
      case SettingsPanel.appearance:
        return const _SettingsSectionView(
          title: 'Appearance',
          description: 'Display readability and shell density.',
          child: SettingsRows(items: appearanceSettings),
        );
      case SettingsPanel.system:
        return const _SettingsSectionView(
          title: 'System',
          description: 'Diagnostics, storage, and environment.',
          child: SettingsRows(items: systemSettings),
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
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 26),
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        DecoratedBox(
          decoration: CrispyShellRoles.infoPlateDecoration(),
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: CrispyOverhaulTokens.medium,
              vertical: CrispyOverhaulTokens.small,
            ),
            child: Text(
              'Google TV-like utility hierarchy: icon, label, value, destination.',
              style: TextStyle(color: CrispyOverhaulTokens.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        child,
      ],
    );
  }
}

class _SourcesSectionView extends StatelessWidget {
  const _SourcesSectionView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Text('Sources', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: CrispyOverhaulTokens.small),
        Text(
          'Source management stays inside Settings with health, auth, and import flow ownership here.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        for (final SourceHealthItem item in sourceHealthItems) ...<Widget>[
          DecoratedBox(
            decoration: CrispyShellRoles.insetPanelDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        item.status,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _statusColor(item.status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.small),
                  Text(item.summary),
                ],
              ),
            ),
          ),
          const SizedBox(height: CrispyOverhaulTokens.medium),
        ],
      ],
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
