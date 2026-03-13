import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../domain/entities/user_profile.dart';

/// TV master-detail layout for the Profile Selection screen.
///
/// Master panel: profile grid (passed as child).
/// Detail panel: profile details (name, avatar, stats) or welcome message.
class ProfileSelectionTvLayout extends StatelessWidget {
  /// Creates the profile selection TV layout.
  const ProfileSelectionTvLayout({
    required this.profileGrid,
    this.selectedProfile,
    super.key,
  });

  /// The profile grid widget to display in the master panel.
  final Widget profileGrid;

  /// Currently focused profile for showing details in the detail pane.
  final UserProfile? selectedProfile;

  @override
  Widget build(BuildContext context) {
    return TvMasterDetailLayout(
      masterPanel: FocusTraversalGroup(child: Center(child: profileGrid)),
      detailPanel:
          selectedProfile != null
              ? _ProfileDetailPane(profile: selectedProfile!)
              : const _ProfileWelcomePane(),
    );
  }
}

class _ProfileWelcomePane extends StatelessWidget {
  const _ProfileWelcomePane();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: CrispySpacing.md),
          Text(
            'Select a profile',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Choose who is watching',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailPane extends StatelessWidget {
  const _ProfileDetailPane({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: 80, color: colorScheme.primary),
          const SizedBox(height: CrispySpacing.md),
          Text(
            profile.name,
            style: textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            profile.role.label,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (profile.hasPIN) ...[
            const SizedBox(height: CrispySpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: CrispySpacing.xs),
                Text(
                  'PIN protected',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
