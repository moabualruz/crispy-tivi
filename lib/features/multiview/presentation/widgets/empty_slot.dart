import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';

/// Named widget for an unoccupied multi-view slot.
///
/// Displays a centered "Add Channel" prompt.
/// The parent [FocusWrapper] in the grid handles tap/select.
class EmptySlot extends StatelessWidget {
  /// Creates an empty slot placeholder.
  const EmptySlot({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 32,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: CrispySpacing.xs),
            Text(
              'Add Channel',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
