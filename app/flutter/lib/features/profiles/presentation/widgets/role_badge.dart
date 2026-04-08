import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/enums/user_role.dart';

/// Small badge showing user role with appropriate styling.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.compact = false});

  /// The user role to display.
  final UserRole role;

  /// Whether to show a compact version (icon only).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = _getRoleStyle(role, theme);

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(CrispySpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.zero,
        ),
        child: Icon(icon, size: 12, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            role.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _getRoleStyle(UserRole role, ThemeData theme) {
    switch (role) {
      case UserRole.admin:
        return (theme.colorScheme.primary, Icons.shield);
      case UserRole.viewer:
        return (theme.colorScheme.tertiary, Icons.visibility);
      case UserRole.restricted:
        return (theme.colorScheme.error, Icons.lock);
    }
  }
}

/// Role indicator for profile avatars.
///
/// Shows a small badge in the corner of the avatar.
class RoleIndicator extends StatelessWidget {
  const RoleIndicator({
    super.key,
    required this.role,
    required this.child,
    this.alignment = Alignment.bottomRight,
  });

  /// The user role to indicate.
  final UserRole role;

  /// The child widget (usually an avatar).
  final Widget child;

  /// Where to position the badge.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // Don't show indicator for regular viewers
    if (role == UserRole.viewer) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: RoleBadge(role: role, compact: true),
          ),
        ),
      ],
    );
  }
}
