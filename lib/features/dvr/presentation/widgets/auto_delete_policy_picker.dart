import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/recording.dart';

/// Compact inline picker for [AutoDeletePolicy] with episode stepper.
///
/// Shows a labelled dropdown and, when [AutoDeletePolicy.keepN] is
/// selected, an additional episode-count stepper row.
///
/// Set [showLabel] to `true` (default) to display the `'AUTO-DELETE POLICY'`
/// section header above the dropdown, or `false` to omit it.
class AutoDeletePolicyPicker extends StatelessWidget {
  const AutoDeletePolicyPicker({
    super.key,
    required this.value,
    required this.keepEpisodeCount,
    required this.onChanged,
    this.showLabel = true,
    this.maxKeepCount = 99,
  });

  final AutoDeletePolicy value;
  final int keepEpisodeCount;
  final void Function(AutoDeletePolicy policy, int count) onChanged;

  /// Whether to show the `'AUTO-DELETE POLICY'` section label.
  final bool showLabel;

  /// Maximum value for the keep-N stepper (e.g. 10 or 99).
  final int maxKeepCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            'AUTO-DELETE POLICY',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
        ],
        InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.delete_sweep_outlined),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: CrispySpacing.xs,
              horizontal: CrispySpacing.sm,
            ),
          ),
          child: DropdownButton<AutoDeletePolicy>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            isDense: true,
            items:
                AutoDeletePolicy.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(p.icon, size: 18),
                            const SizedBox(width: CrispySpacing.sm),
                            Text(p.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (p) {
              if (p != null) onChanged(p, keepEpisodeCount);
            },
          ),
        ),
        if (value == AutoDeletePolicy.keepN) ...[
          const SizedBox(height: CrispySpacing.sm),
          Row(
            children: [
              const SizedBox(width: CrispySpacing.xl),
              Text('Keep latest', style: tt.bodyMedium),
              const SizedBox(width: CrispySpacing.sm),
              IconButton.outlined(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed:
                    keepEpisodeCount > 1
                        ? () => onChanged(value, keepEpisodeCount - 1)
                        : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                ),
                child: Text(
                  '$keepEpisodeCount',
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton.outlined(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed:
                    keepEpisodeCount < maxKeepCount
                        ? () => onChanged(value, keepEpisodeCount + 1)
                        : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: CrispySpacing.sm),
              Text('episodes', style: tt.bodyMedium),
            ],
          ),
        ],
      ],
    );
  }
}
