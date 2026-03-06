import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/settings_notifier.dart';
import '../../core/domain/entities/playlist_source_type_ext.dart';
import '../providers/source_filter_provider.dart';
import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';

/// Horizontally scrollable chip bar that lets users filter
/// content by source.
///
/// Renders nothing when 0 or 1 source is configured — a
/// single source requires no filtering UI. Shows an "All
/// Sources" chip first, then one chip per configured source.
///
/// Chip selection is mirrored in [sourceFilterProvider]:
/// - Empty set → "All Sources" selected.
/// - Non-empty set → specific sources selected.
///
/// Usage:
/// ```dart
/// const SourceSelectorBar()
/// ```
class SourceSelectorBar extends ConsumerWidget {
  const SourceSelectorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources =
        ref.watch(settingsNotifierProvider).asData?.value.sources ?? const [];

    // No bar needed when fewer than 2 sources are configured.
    if (sources.length <= 1) return const SizedBox.shrink();

    final sourceFilter = ref.watch(sourceFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final chips = <Widget>[
      _SourceChip(
        label: 'All Sources',
        icon: null,
        isSelected: sourceFilter.isEmpty,
        colorScheme: colorScheme,
        textTheme: textTheme,
        onTap: () => ref.read(sourceFilterProvider.notifier).selectAll(),
      ),
      ...sources.map(
        (source) => _SourceChip(
          label: source.name,
          icon: source.type.icon,
          isSelected: sourceFilter.contains(source.id),
          colorScheme: colorScheme,
          textTheme: textTheme,
          onTap:
              () => ref.read(sourceFilterProvider.notifier).toggle(source.id),
        ),
      ),
    ];

    return SizedBox(
      height: _kBarHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: CrispySpacing.sm),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }
}

/// Height of the bar container (chip height + vertical padding).
const double _kBarHeight = 44.0;

/// A single tappable source chip with an optional type icon.
class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest;

    final fgColor =
        isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Semantics(
      label: '$label source filter',
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            border: Border.all(
              color:
                  isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fgColor),
                const SizedBox(width: CrispySpacing.xs),
              ],
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
