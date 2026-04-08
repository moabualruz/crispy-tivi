import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/sync_conflict.dart';
import '../providers/cloud_sync_providers.dart';
import 'google_sign_in_button.dart';
import 'sync_conflict_dialog.dart';
import 'sync_status_indicator.dart';

/// Complete cloud sync settings section.
///
/// Includes sign-in, sync status, sync controls, and options.
class CloudSyncSection extends ConsumerWidget {
  const CloudSyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_sync,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                context.l10n.cloudSyncTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GoogleSignInButton(),
                if (state.isSignedIn) ...[
                  const SizedBox(height: CrispySpacing.lg),
                  const SyncStatusIndicator(),
                  const Divider(height: CrispySpacing.xl),
                  _buildSyncControls(context, ref, state),
                  const Divider(height: CrispySpacing.xl),
                  _buildSyncOptions(context, ref, state),
                ],
              ],
            ),
          ),
        ),
        if (state.isSignedIn)
          Padding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            child: Text(
              'Your data is synced to Google Drive app storage. '
              'It\'s private and auto-deleted if you uninstall the app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSyncControls(
    BuildContext context,
    WidgetRef ref,
    CloudSyncState state,
  ) {
    final isSyncing = state.status == SyncStatus.syncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: isSyncing ? null : () => _syncNow(context, ref),
          icon:
              isSyncing
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.sync),
          label: Text(
            isSyncing
                ? context.l10n.cloudSyncSyncing
                : context.l10n.cloudSyncNow,
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSyncing ? null : () => _forceUpload(context, ref),
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: Text(context.l10n.cloudSyncForceUpload),
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    isSyncing ? null : () => _forceDownload(context, ref),
                icon: const Icon(Icons.cloud_download, size: 18),
                label: Text(context.l10n.cloudSyncForceDownload),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncOptions(
    BuildContext context,
    WidgetRef ref,
    CloudSyncState state,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.l10n.cloudSyncAutoSync),
      subtitle: const Text('Sync automatically on app start'),
      value: state.isAutoSyncEnabled,
      onChanged: (value) {
        ref.read(cloudSyncProvider.notifier).setAutoSyncEnabled(value);
      },
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(cloudSyncProvider.notifier).syncNow();

    if (!context.mounted) return;

    if (result.success) {
      _showSnackBar(context, 'Sync complete', isError: false);
    } else if (result.error?.contains('conflict') ?? false) {
      await _handleConflict(context, ref);
    } else {
      _showSnackBar(context, result.error ?? 'Sync failed', isError: true);
    }
  }

  Future<void> _forceUpload(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmAction(
      context,
      title: 'Force Upload',
      message: 'This will overwrite cloud data with your local data. Continue?',
    );

    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(cloudSyncProvider.notifier).forceUpload();

    if (!context.mounted) return;

    if (result.success) {
      _showSnackBar(context, 'Upload complete', isError: false);
    } else {
      _showSnackBar(context, result.error ?? 'Upload failed', isError: true);
    }
  }

  Future<void> _forceDownload(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmAction(
      context,
      title: 'Force Download',
      message: 'This will overwrite your local data with cloud data. Continue?',
    );

    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(cloudSyncProvider.notifier).forceDownload();

    if (!context.mounted) return;

    if (result.success) {
      _showSnackBar(
        context,
        'Download complete (${result.itemsSynced} items)',
        isError: false,
      );
    } else {
      _showSnackBar(context, result.error ?? 'Download failed', isError: true);
    }
  }

  Future<void> _handleConflict(BuildContext context, WidgetRef ref) async {
    // Get conflict details from the service.
    final syncService = ref.read(cloudSyncServiceProvider);
    final conflict = await syncService.getConflictDetails();

    if (conflict == null || !context.mounted) return;

    final resolution = await SyncConflictDialog.show(context, conflict);

    if (resolution == null ||
        resolution == ConflictResolution.cancel ||
        !context.mounted) {
      return;
    }

    final result = await ref
        .read(cloudSyncProvider.notifier)
        .syncNow(conflictResolution: resolution);

    if (!context.mounted) return;

    if (result.success) {
      _showSnackBar(context, 'Conflict resolved', isError: false);
    } else {
      _showSnackBar(context, result.error ?? 'Sync failed', isError: true);
    }
  }

  Future<bool?> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }
}
