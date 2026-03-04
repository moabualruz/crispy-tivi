import 'package:flutter/material.dart';

import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/utils/duration_formatter.dart';

/// Compact countdown badge shown in the OSD top bar
/// when a sleep timer is active.
class SleepTimerBadge extends StatelessWidget {
  const SleepTimerBadge({
    required this.remaining,
    required this.colorScheme,
    super.key,
  });

  final Duration remaining;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final label = DurationFormatter.clock(remaining);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.2),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: colorScheme.primary, size: 14),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
