import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../providers/cloud_sync_providers.dart';

/// Button for Google Sign-In with proper branding.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncProvider);

    if (state.isSignedIn) {
      return _SignedInTile(
        email: state.userEmail ?? '',
        displayName: state.userDisplayName,
        photoUrl: state.userPhotoUrl,
        onSignOut: () => _handleSignOut(context, ref),
      );
    }

    return _SignInButton(
      isLoading: state.status == SyncStatus.syncing,
      onPressed: () => _handleSignIn(context, ref),
    );
  }

  Future<void> _handleSignIn(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(cloudSyncProvider.notifier).signIn();
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in cancelled or failed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text(
              'Are you sure you want to sign out from Google?\n\n'
              'Your local data will remain, but cloud sync will be disabled.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(cloudSyncProvider.notifier).signOut();
    }
  }
}

/// Sign-in button following Google branding guidelines.
class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.outline),
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.lg,
          vertical: CrispySpacing.md,
        ),
        shape: const RoundedRectangleBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            _buildGoogleLogo(),
          const SizedBox(width: CrispySpacing.md),
          const Text('Sign in with Google'),
        ],
      ),
    );
  }

  Widget _buildGoogleLogo() {
    // Google "G" logo using Material icon fallback
    // In production, use actual Google branding assets
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4), // Google Blue
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Tile showing signed-in user info.
class _SignedInTile extends StatelessWidget {
  const _SignedInTile({
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.onSignOut,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Row(
          children: [
            _buildAvatar(theme),
            const SizedBox(width: CrispySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName != null)
                    Text(displayName!, style: theme.textTheme.titleMedium),
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: onSignOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          image: DecorationImage(
            image: NetworkImage(photoUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        (displayName ?? email).isNotEmpty
            ? (displayName ?? email)[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
