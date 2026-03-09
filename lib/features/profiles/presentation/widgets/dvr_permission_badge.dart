import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/enums/dvr_permission.dart';

/// Small badge showing DVR permission level.
///
/// Used in [ProfileManagementTile] to indicate the DVR access
/// granted to a profile (none / view-only / full).
class DvrPermissionBadge extends StatelessWidget {
  const DvrPermissionBadge({required this.permission, super.key});

  final DvrPermission permission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = _getStyle(permission, theme);

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
            'DVR: ${permission.label}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _getStyle(DvrPermission perm, ThemeData theme) {
    switch (perm) {
      case DvrPermission.none:
        return (theme.colorScheme.error, Icons.block);
      case DvrPermission.viewOnly:
        return (theme.colorScheme.tertiary, Icons.visibility);
      case DvrPermission.full:
        return (theme.colorScheme.primary, Icons.videocam);
    }
  }
}
