import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';

/// A horizontal "or" divider row used between alternative login options.
///
/// Renders: `── or ──` with theme-appropriate styling.
///
/// The label text uses [TextTheme.labelMedium] with [ColorScheme.onSurfaceVariant]
/// and the dividers use [ColorScheme.outline] at 50 % opacity to match
/// the login-screen design language across Emby, Jellyfin, and Plex.
class OrDividerRow extends StatelessWidget {
  const OrDividerRow({super.key, this.label = 'or'});

  /// Text displayed between the two divider lines. Defaults to `'or'`.
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.5))),
      ],
    );
  }
}
