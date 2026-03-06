import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_spacing.dart';
import 'player_gesture_overlays.dart' show SwipeType;

/// Inline volume/brightness level indicator shown
/// during vertical swipe gestures.
class SwipeIndicator extends StatelessWidget {
  const SwipeIndicator({
    required this.isSwiping,
    required this.swipeType,
    required this.value,
    required this.isInPip,
    super.key,
  });

  final bool isSwiping;
  final SwipeType? swipeType;

  /// Current level (0.0–1.0).
  final double value;
  final bool isInPip;

  @override
  Widget build(BuildContext context) {
    if (!isSwiping || isInPip) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      top: CrispySpacing.xl,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.lg,
            vertical: CrispySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: CrispyColors.scrimMid,
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                swipeType == SwipeType.volume
                    ? Icons.volume_up
                    : Icons.brightness_6,
                color: colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: CrispySpacing.sm),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.24,
                  ),
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brief channel name popup shown after zapping.
class ZapNameOverlay extends StatelessWidget {
  const ZapNameOverlay({
    required this.channelName,
    required this.isInPip,
    super.key,
  });

  final String? channelName;
  final bool isInPip;

  @override
  Widget build(BuildContext context) {
    if (channelName == null || isInPip) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Positioned(
      top: CrispySpacing.xxl,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.lg,
            vertical: CrispySpacing.md,
          ),
          decoration: BoxDecoration(
            color: CrispyColors.scrimHeavy,
            borderRadius: BorderRadius.zero,
          ),
          child: Text(
            channelName!,
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Invisible hit zone along the right edge that
/// detects a left-swipe to open the channel zap
/// overlay.
class RightEdgeZapZone extends StatelessWidget {
  const RightEdgeZapZone({
    required this.edgeThreshold,
    required this.onSwipeLeft,
    super.key,
  });

  final double edgeThreshold;
  final VoidCallback onSwipeLeft;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: edgeThreshold,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200) {
            onSwipeLeft();
          }
        },
      ),
    );
  }
}
