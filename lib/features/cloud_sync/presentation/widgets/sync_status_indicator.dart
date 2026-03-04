import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../providers/cloud_sync_providers.dart';

/// Widget showing current sync status with visual indicator.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncProvider);
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIcon(state, theme),
        const SizedBox(width: CrispySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getStatusText(state), style: theme.textTheme.bodyMedium),
              if (state.lastSyncTime != null)
                Text(
                  'Last synced ${formatRelativeTime(state.lastSyncTime!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (state.error != null)
                Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(CloudSyncState state, ThemeData theme) {
    switch (state.status) {
      case SyncStatus.notSignedIn:
        return Icon(Icons.cloud_off, color: theme.colorScheme.outline);
      case SyncStatus.idle:
        return Icon(Icons.cloud_done, color: theme.colorScheme.primary);
      case SyncStatus.syncing:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        );
      case SyncStatus.success:
        return Icon(Icons.cloud_done, color: theme.colorScheme.primary);
      case SyncStatus.error:
        return Icon(Icons.cloud_off, color: theme.colorScheme.error);
    }
  }

  String _getStatusText(CloudSyncState state) {
    switch (state.status) {
      case SyncStatus.notSignedIn:
        return 'Not signed in';
      case SyncStatus.idle:
        return 'Connected';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Sync complete';
      case SyncStatus.error:
        return 'Sync error';
    }
  }
}

/// Small sync status chip for compact display.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncProvider);
    final theme = Theme.of(context);

    if (!state.isSignedIn) {
      return const SizedBox.shrink();
    }

    final (icon, color) = _getIconAndColor(state, theme);

    return Tooltip(
      message: _getTooltip(state),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.sm,
          vertical: CrispySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.status == SyncStatus.syncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: CrispySpacing.xs),
            Text(
              _getChipText(state),
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _getIconAndColor(CloudSyncState state, ThemeData theme) {
    switch (state.status) {
      case SyncStatus.notSignedIn:
        return (Icons.cloud_off, theme.colorScheme.outline);
      case SyncStatus.idle:
      case SyncStatus.success:
        return (Icons.cloud_done, theme.colorScheme.primary);
      case SyncStatus.syncing:
        return (Icons.cloud_sync, theme.colorScheme.primary);
      case SyncStatus.error:
        return (Icons.cloud_off, theme.colorScheme.error);
    }
  }

  String _getChipText(CloudSyncState state) {
    switch (state.status) {
      case SyncStatus.notSignedIn:
        return 'Offline';
      case SyncStatus.idle:
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.error:
        return 'Error';
    }
  }

  String _getTooltip(CloudSyncState state) {
    if (state.lastSyncTime != null) {
      final time = state.lastSyncTime!.toLocal();
      return 'Last synced: ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
    return _getChipText(state);
  }
}
