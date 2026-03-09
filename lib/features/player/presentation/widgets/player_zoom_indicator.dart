import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';

// ─────────────────────────────────────────────────────────────
// FE-PS-19: Zoom percentage HUD overlay
// ─────────────────────────────────────────────────────────────

/// Centered glassmorphic badge showing the current zoom level.
///
/// Shown while pinching and briefly after the gesture ends.
/// Fades when [visible] is false (gesture ended).
class PlayerZoomIndicator extends StatelessWidget {
  const PlayerZoomIndicator({
    required this.label,
    required this.visible,
    super.key,
  });

  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.6,
        duration: CrispyAnimation.osdShow,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(CrispyRadius.sm),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.15)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
