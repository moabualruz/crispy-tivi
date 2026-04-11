import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:flutter/material.dart';

class SettingsRows extends StatelessWidget {
  const SettingsRows({required this.items, super.key});

  final List<SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CrispyOverhaulTokens.surfaceInset,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
        border: Border.all(color: CrispyOverhaulTokens.borderStrong),
      ),
      child: Column(
        children: items
            .map((SettingsItem item) => _SettingsRow(item: item))
            .toList(growable: false),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.item});

  final SettingsItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final IconData icon = _iconForTitle(item.title);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispyOverhaulTokens.large,
        vertical: CrispyOverhaulTokens.medium,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CrispyOverhaulTokens.surfaceHighlight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: CrispyOverhaulTokens.textSecondary),
          ),
          const SizedBox(width: CrispyOverhaulTokens.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: textTheme.titleMedium),
                const SizedBox(height: CrispyOverhaulTokens.compact),
                Text(item.summary, style: textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: CrispyOverhaulTokens.medium),
          Text(
            item.value,
            style: textTheme.bodyLarge?.copyWith(
              color: CrispyOverhaulTokens.textSecondary,
            ),
          ),
          const SizedBox(width: CrispyOverhaulTokens.small),
          const Icon(
            Icons.chevron_right,
            color: CrispyOverhaulTokens.textMuted,
          ),
        ],
      ),
    );
  }

  IconData _iconForTitle(String title) {
    switch (title) {
      case 'Startup target':
        return Icons.home_outlined;
      case 'Recommendations':
        return Icons.auto_awesome_outlined;
      case 'Quick play confirmation':
        return Icons.play_circle_outline;
      case 'Preferred quality':
        return Icons.high_quality_outlined;
      case 'Focus intensity':
        return Icons.visibility_outlined;
      case 'Clock display':
        return Icons.schedule_outlined;
      case 'Storage':
        return Icons.storage_outlined;
      case 'About':
        return Icons.info_outline;
      default:
        return Icons.settings_outlined;
    }
  }
}
