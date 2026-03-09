import 'package:flutter/material.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../domain/entities/sync_conflict.dart';

/// Dialog for resolving sync conflicts between local and cloud data.
class SyncConflictDialog extends StatelessWidget {
  const SyncConflictDialog({
    super.key,
    required this.conflict,
    required this.onResolution,
  });

  final SyncConflict conflict;
  final void Function(ConflictResolution) onResolution;

  /// Shows the dialog and returns the selected resolution.
  static Future<ConflictResolution?> show(
    BuildContext context,
    SyncConflict conflict,
  ) {
    return showDialog<ConflictResolution>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => SyncConflictDialog(
            conflict: conflict,
            onResolution: (resolution) => Navigator.pop(ctx, resolution),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: theme.colorScheme.error),
          const SizedBox(width: CrispySpacing.sm),
          Text(context.l10n.cloudSyncConflict),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your data has been modified on another device. '
              'Choose how to resolve this conflict:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: CrispySpacing.lg),
            _buildComparisonCard(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => onResolution(ConflictResolution.cancel),
          child: Text(context.l10n.commonCancel),
        ),
        const SizedBox(width: CrispySpacing.xs),
        _buildResolutionChip(
          context,
          label: context.l10n.cloudSyncKeepLocal,
          icon: Icons.phone_android,
          description: 'Use this device\'s data',
          resolution: ConflictResolution.keepLocal,
          isRecommended: conflict.isLocalNewer,
        ),
        _buildResolutionChip(
          context,
          label: context.l10n.cloudSyncKeepRemote,
          icon: Icons.cloud,
          description: 'Use cloud data',
          resolution: ConflictResolution.keepCloud,
          isRecommended: conflict.isCloudNewer,
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.all(CrispySpacing.md),
    );
  }

  Widget _buildComparisonCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Row(
          children: [
            Expanded(
              child: _buildDataColumn(
                context,
                title: context.l10n.cloudSyncThisDevice,
                icon: Icons.phone_android,
                time: conflict.localModifiedTime,
                deviceId: conflict.localDeviceId,
                isNewer: conflict.isLocalNewer,
              ),
            ),
            Container(
              width: 1,
              height: 80,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              child: _buildDataColumn(
                context,
                title: context.l10n.cloudSyncCloud,
                icon: Icons.cloud,
                time: conflict.cloudModifiedTime,
                deviceId: conflict.cloudDeviceId,
                isNewer: conflict.isCloudNewer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataColumn(
    BuildContext context, {
    required String title,
    required IconData icon,
    required DateTime time,
    String? deviceId,
    required bool isNewer,
  }) {
    final theme = Theme.of(context);
    final localTime = time.toLocal();

    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color:
              isNewer ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        const SizedBox(height: CrispySpacing.sm),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isNewer ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: CrispySpacing.xs),
        Text(
          _formatDateTime(localTime),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (isNewer)
          Padding(
            padding: const EdgeInsets.only(top: CrispySpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                context.l10n.cloudSyncNewer,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResolutionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String description,
    required ConflictResolution resolution,
    bool isRecommended = false,
  }) {
    return Tooltip(
      message: description,
      child:
          isRecommended
              ? FilledButton.icon(
                onPressed: () => onResolution(resolution),
                icon: Icon(icon, size: 18),
                label: Text(label),
              )
              : OutlinedButton.icon(
                onPressed: () => onResolution(resolution),
                icon: Icon(icon, size: 18),
                label: Text(label),
              ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final timeStr = formatHHmm(dt);

    if (diff.inDays == 0) {
      return 'Today at $timeStr';
    } else if (diff.inDays == 1) {
      return 'Yesterday at $timeStr';
    } else {
      return '${dt.month}/${dt.day} at $timeStr';
    }
  }
}
