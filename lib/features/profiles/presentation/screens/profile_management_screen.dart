import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/widgets/async_value_ui.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../data/profile_service.dart';
import '../profile_constants.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/dvr_permission.dart';
import '../../domain/enums/user_role.dart';
import '../widgets/profile_management_widgets.dart';
import '../widgets/source_access_dialog.dart';

/// Admin-only screen for managing user profiles.
///
/// Allows admins to:
/// - View all profiles with their roles and permissions
/// - Change profile roles (admin, viewer, restricted)
/// - Change DVR permissions (none, viewOnly, full)
/// - Manage source access per profile
class ProfileManagementScreen extends ConsumerWidget {
  const ProfileManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(profileServiceProvider);

    return Scaffold(
      key: TestKeys.profileManagementScreen,
      appBar: AppBar(title: Text(context.l10n.profilesManage)),
      body: stateAsync.whenUi(
        onRetry: () => ref.invalidate(profileServiceProvider),
        data: (state) => _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ProfileState state) {
    final currentProfile = state.activeProfile;
    final colorScheme = Theme.of(context).colorScheme;

    // Only admins should see this screen
    if (currentProfile == null || !currentProfile.isAdmin) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 64, color: colorScheme.error),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'Admin Access Required',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              'Only admins can manage profiles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (state.profiles.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No profiles found',
        description: 'Create a profile to get started.',
        onRefresh: () => ref.invalidate(profileServiceProvider),
      );
    }

    // PM-07: constrain content width for TV/large screens.
    return FocusTraversalGroup(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            padding: const EdgeInsets.all(CrispySpacing.md),
            itemCount: state.profiles.length,
            itemBuilder: (context, index) {
              final profile = state.profiles[index];
              return ProfileManagementTile(
                profile: profile,
                isCurrentUser: profile.id == currentProfile.id,
                icon:
                    kProfileAvatarIcons[profile.avatarIndex %
                        kProfileAvatarIcons.length],
                color:
                    kProfileAvatarColors[profile.avatarIndex %
                        kProfileAvatarColors.length],
                onRoleChanged:
                    (newRole) => _changeRole(context, ref, profile, newRole),
                onDvrPermissionChanged:
                    (newPerm) =>
                        _changeDvrPermission(context, ref, profile, newPerm),
                onManageSources:
                    () => _showSourceAccessDialog(context, profile),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    UserRole newRole,
  ) async {
    // PM-09: Show confirmation before changing the role.
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Change Role'),
            content: Text(
              'Change ${profile.name}\'s role to '
              '"${newRole.label}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.commonConfirm),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final success = await ref
        .read(profileServiceProvider.notifier)
        .updateProfileRole(profile.id, newRole);

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot change role. You may be the last admin.'),
        ),
      );
    }
  }

  Future<void> _changeDvrPermission(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    DvrPermission newPerm,
  ) async {
    final success = await ref
        .read(profileServiceProvider.notifier)
        .updateProfileDvrPermission(profile.id, newPerm);

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change DVR permission.')),
      );
    }
  }

  void _showSourceAccessDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => SourceAccessDialog(profile: profile),
    );
  }
}
