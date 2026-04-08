import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_colors.dart';
import '../theme/crispy_radius.dart';
import 'focus_wrapper.dart';

/// Navigation arrow overlay for horizontal scroll carousels.
///
/// Renders a gradient container with a chevron icon. Hover
/// darkens the gradient; the focus ring is suppressed (arrow
/// is a supplementary affordance, not the primary focus target).
///
/// Used by both [HorizontalScrollRow] and [VodRow] to avoid
/// duplicating the identical stateful widget.
class NavArrow extends StatefulWidget {
  /// Creates a navigation arrow.
  const NavArrow({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isLeft,
    required this.iconSize,
  });

  /// Chevron icon (typically [Icons.chevron_left] or
  /// [Icons.chevron_right]).
  final IconData icon;

  /// Called when the arrow is tapped or activated via keyboard.
  final VoidCallback onTap;

  /// Whether this is the left arrow. Controls gradient direction.
  final bool isLeft;

  /// Size of the chevron icon.
  final double iconSize;

  @override
  State<NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<NavArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusWrapper(
      onSelect: widget.onTap,
      borderRadius: CrispyRadius.md,
      scaleFactor: CrispyAnimation.hoverScale,
      focusBorderWidth: 0,
      showFocusOverlay: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CrispyRadius.md),
            gradient: LinearGradient(
              colors: [
                _isHovered
                    ? Colors.black.withValues(alpha: 0.9)
                    : Colors.black87,
                Colors.transparent,
              ],
              begin:
                  widget.isLeft ? Alignment.centerLeft : Alignment.centerRight,
              end: widget.isLeft ? Alignment.centerRight : Alignment.centerLeft,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            color: CrispyColors.textHigh,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}
