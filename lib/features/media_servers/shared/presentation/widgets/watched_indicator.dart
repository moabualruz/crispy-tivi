import 'package:flutter/material.dart';

import '../../../../../core/theme/crispy_spacing.dart';

/// Overlay widget showing watched/in-progress status on media cards.
///
/// Place inside a [Stack] positioned over the card image.
/// Shows:
/// - Green checkmark badge (top-right) for fully watched items
/// - Progress bar (bottom) for in-progress items
class WatchedIndicator extends StatelessWidget {
  const WatchedIndicator({
    required this.isWatched,
    required this.isInProgress,
    this.watchProgress,
    super.key,
  });

  /// Whether the item has been fully watched.
  final bool isWatched;

  /// Whether the item is in progress (started but not finished).
  final bool isInProgress;

  /// Watch progress as a value between 0.0 and 1.0.
  final double? watchProgress;

  @override
  Widget build(BuildContext context) {
    // Fully watched: show checkmark badge
    if (isWatched) {
      return Positioned(
        top: CrispySpacing.xs,
        right: CrispySpacing.xs,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.26),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.check,
            size: 14,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

    // In progress: show progress bar at bottom
    if (isInProgress && watchProgress != null && watchProgress! > 0) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: LinearProgressIndicator(
          value: watchProgress,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: 0.45),
          minHeight: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // No indicator needed
    return const SizedBox.shrink();
  }
}
