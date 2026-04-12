import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
import 'package:flutter/material.dart';

class SettingsRows extends StatelessWidget {
  const SettingsRows({
    required this.items,
    this.sectionLabel,
    this.sectionSummary,
    this.highlightedItemIndex,
    super.key,
  });

  final List<SettingsItem> items;
  final String? sectionLabel;
  final String? sectionSummary;
  final int? highlightedItemIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (sectionLabel != null) ...<Widget>[
              _SectionHeader(label: sectionLabel!, summary: sectionSummary),
              const SizedBox(height: CrispyOverhaulTokens.medium),
            ],
            DecoratedBox(
              decoration: CrispyShellRoles.insetPanelDecoration(),
              child: Column(
                children: items
                    .asMap()
                    .entries
                    .map(
                      (MapEntry<int, SettingsItem> entry) => _SettingsRow(
                        item: entry.value,
                        highlighted: highlightedItemIndex == entry.key,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.summary});

  final String label;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ShellIconPlate(
          icon: CrispyShellIcons.settingsPanel(_settingsPanelForLabel(label)),
          role: ShellIconRole.row,
        ),
        const SizedBox(width: CrispyOverhaulTokens.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              if (summary != null) ...<Widget>[
                const SizedBox(height: CrispyOverhaulTokens.compact),
                Text(
                  summary!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.item, required this.highlighted});

  final SettingsItem item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final IconData icon = CrispyShellIcons.settingsRow(item.title);
    return DecoratedBox(
      decoration:
          highlighted
              ? BoxDecoration(
                color: CrispyOverhaulTokens.navSelectedBackground,
                border: Border.all(
                  color: CrispyOverhaulTokens.navSelectedBorder,
                ),
                borderRadius: BorderRadius.circular(
                  CrispyOverhaulTokens.radiusControl,
                ),
              )
              : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CrispyOverhaulTokens.borderStrong),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.large,
          vertical: CrispyOverhaulTokens.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ShellIconPlate(
              icon: icon,
              role: ShellIconRole.row,
              color:
                  highlighted
                      ? CrispyOverhaulTokens.navSelectedText
                      : CrispyOverhaulTokens.textSecondary,
            ),
            const SizedBox(width: CrispyOverhaulTokens.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: textTheme.titleMedium?.copyWith(
                      color:
                          highlighted
                              ? CrispyOverhaulTokens.navSelectedText
                              : CrispyOverhaulTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.compact),
                  Text(
                    item.summary,
                    style: textTheme.bodyMedium?.copyWith(
                      color:
                          highlighted
                              ? CrispyOverhaulTokens.navSelectedText
                              : CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CrispyOverhaulTokens.medium),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  item.value,
                  style: textTheme.bodyLarge?.copyWith(
                    color:
                        highlighted
                            ? CrispyOverhaulTokens.navSelectedText
                            : CrispyOverhaulTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: CrispyOverhaulTokens.compact),
                ShellIconGraphic(
                  icon: Icons.chevron_right,
                  role: ShellIconRole.compact,
                  color:
                      highlighted
                          ? CrispyOverhaulTokens.navSelectedText
                          : CrispyOverhaulTokens.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

SettingsPanel _settingsPanelForLabel(String label) {
  switch (label) {
    case 'General settings':
      return SettingsPanel.general;
    case 'Playback settings':
      return SettingsPanel.playback;
    case 'Appearance settings':
      return SettingsPanel.appearance;
    case 'System settings':
      return SettingsPanel.system;
    default:
      return SettingsPanel.general;
  }
}
