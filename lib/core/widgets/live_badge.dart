import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_colors.dart';
import '../theme/crispy_spacing.dart';

/// Pulsing red "LIVE" indicator badge per
/// `.ai/docs/project-specs/design_system.md §2` and `ui_ux_spec.md §3.5`.
///
/// Animates: scale 1↔1.2 + opacity, 2s loop.
///
/// ```dart
/// LiveBadge()
/// LiveBadge(label: 'REC', color: crispyColors.recordingRed)
/// ```
class LiveBadge extends StatefulWidget {
  const LiveBadge({
    this.label = 'LIVE',
    this.color,
    this.dotSize = 8.0,
    super.key,
  });

  /// Text label. Defaults to "LIVE".
  final String label;

  /// Badge color. Defaults to [CrispyColors.liveRed].
  final Color? color;

  /// Diameter of the pulsing dot.
  final double dotSize;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CrispyAnimation.livePulse,
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.color ?? Theme.of(context).crispyColors.liveRed;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder:
                (context, child) =>
                    Transform.scale(scale: _scale.value, child: child),
            child: Container(
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.rectangle,
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            widget.label,
            style: textTheme.labelSmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
