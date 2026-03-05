import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';

/// Positioned star overlay for favorite toggle.
///
/// - When [isFavorite] is `true`: always shows a filled
///   amber star.
/// - When [isFavorite] is `false` and [isHovered] is
///   `true`: shows an outlined star that the user can
///   click.
/// - When both are `false`: hidden.
///
/// The [onToggle] callback fires when the star is tapped.
class FavoriteStarOverlay extends StatelessWidget {
  const FavoriteStarOverlay({
    super.key,
    required this.isFavorite,
    required this.isHovered,
    required this.onToggle,
    this.size = 22,
  });

  /// Whether the item is currently favorited.
  final bool isFavorite;

  /// Whether the parent widget is being hovered.
  final bool isHovered;

  /// Called when the star is tapped to toggle.
  final VoidCallback onToggle;

  /// Icon size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final show = isFavorite || isHovered;

    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: CrispyAnimation.fast,
      child: Semantics(
        button: true,
        label: 'Toggle favorite',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isFavorite ? Colors.black54 : Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: isFavorite ? Colors.amber : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
