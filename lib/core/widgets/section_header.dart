import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';

/// Reusable section header with an optional leading icon and
/// optional trailing widget.
///
/// Unifies the repeated header pattern found in home-screen rows,
/// settings sections, and VOD browser sections.
///
/// ```dart
/// SectionHeader(
///   title: 'Top 10 Today',
///   icon: Icons.trending_up,
/// )
///
/// // Settings variant — tint the title with the primary color:
/// SectionHeader(
///   title: 'Playback',
///   icon: Icons.play_circle_outline,
///   colorTitle: true,
/// )
/// ```
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.colorTitle = false,
  });

  /// Primary text displayed in the header.
  final String title;

  /// Optional leading icon. Rendered at 20 px in the primary color.
  final IconData? icon;

  /// Optional widget placed at the trailing end of the row.
  final Widget? trailing;

  /// When true, the title is tinted with [ColorScheme.primary].
  /// Default is false (uses the default [TextTheme.titleMedium] color).
  final bool colorTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: CrispySpacing.sm),
        ],
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorTitle ? colorScheme.primary : null,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
