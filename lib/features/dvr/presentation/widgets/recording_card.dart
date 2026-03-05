import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../data/dvr_service.dart';
import '../../data/transfer_service.dart';
import '../../domain/entities/recording.dart';
import '../../domain/entities/recording_profile.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/recording_quality.dart';
import 'auto_delete_policy_dialog.dart';

/// Card widget displaying a single [Recording] with
/// status icon, metadata, cloud badge, quality badge,
/// auto-delete policy badge, and action menu.
///
/// Tapping a completed or in-progress recording starts
/// playback. A play icon overlay appears on the status
/// area for playable recordings, and a progress bar is
/// shown when a saved playback position exists.
class RecordingCard extends ConsumerWidget {
  /// Creates a recording card.
  const RecordingCard({super.key, required this.recording});

  /// The recording to display.
  final Recording recording;

  /// Whether this recording can be played back.
  bool get _isPlayable =>
      recording.status == RecordingStatus.completed ||
      recording.status == RecordingStatus.recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // Derive a consistent history ID from the file path or
    // stream URL, mirroring the WatchHistoryService convention.
    final historyId =
        recording.filePath != null && recording.filePath!.isNotEmpty
            ? WatchHistoryService.deriveId(recording.filePath!)
            : recording.streamUrl != null && recording.streamUrl!.isNotEmpty
            ? WatchHistoryService.deriveId(recording.streamUrl!)
            : null;

    // Watch saved playback progress (null = not started / completed).
    final progressAsync =
        historyId != null
            ? ref.watch(watchProgressProvider(historyId))
            : const AsyncData<double?>(null);
    final progress = progressAsync.value;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      child: FocusWrapper(
        borderRadius: CrispyRadius.md,
        onSelect: () => _onCardTap(context, ref),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: _PlayableStatusIcon(
                recording: recording,
                isPlayable: _isPlayable,
              ),
              title: Text(
                recording.programName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recording.channelName} · '
                    '${formatHHmm(recording.startTime)}'
                    ' – '
                    '${formatHHmm(recording.endTime)}',
                  ),
                  Row(
                    children: [
                      if (recording.isRecurring) ...[
                        Icon(Icons.repeat, size: 14, color: cs.primary),
                        const SizedBox(width: CrispySpacing.xs),
                        Text(
                          'Recurring',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: cs.primary),
                        ),
                        const SizedBox(width: CrispySpacing.sm),
                      ],
                      _CloudStatusBadge(recording: recording),
                      const SizedBox(width: CrispySpacing.sm),
                      _AutoDeleteBadge(recording: recording),
                      const SizedBox(width: CrispySpacing.sm),
                      _QualityBadge(profile: recording.profile),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSizeDisplay(context, ref),
                  const SizedBox(width: CrispySpacing.sm),
                  PopupMenuButton<String>(
                    tooltip: 'Recording options',
                    onSelected: (action) async {
                      await _onMenuAction(action, context, ref);
                    },
                    itemBuilder: (_) => _menuItems(),
                  ),
                ],
              ),
            ),
            // Progress bar shown when a saved position exists.
            if (progress != null && progress > 0)
              _PlaybackProgressBar(progress: progress),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _menuItems() {
    return [
      if (recording.status == RecordingStatus.recording)
        const PopupMenuItem(
          value: 'stop',
          child: Row(
            children: [
              Icon(Icons.stop, size: 20),
              SizedBox(width: CrispySpacing.sm),
              Text('Stop'),
            ],
          ),
        ),
      if (recording.status == RecordingStatus.completed)
        const PopupMenuItem(
          value: 'play',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 20),
              SizedBox(width: CrispySpacing.sm),
              Text('Play'),
            ],
          ),
        ),
      if (recording.status == RecordingStatus.completed &&
          recording.remoteBackendId == null)
        const PopupMenuItem(
          value: 'upload',
          child: Row(
            children: [
              Icon(Icons.cloud_upload, size: 20),
              SizedBox(width: CrispySpacing.sm),
              Text('Upload to Cloud'),
            ],
          ),
        ),
      if (recording.remoteBackendId != null && recording.filePath == null)
        const PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.cloud_download, size: 20),
              SizedBox(width: CrispySpacing.sm),
              Text('Download'),
            ],
          ),
        ),
      // FE-DVR-12: Save to Device (export stub)
      if (recording.status == RecordingStatus.completed &&
          recording.filePath != null)
        const PopupMenuItem(
          value: 'save_to_device',
          child: Row(
            children: [
              Icon(Icons.save_alt, size: 20),
              SizedBox(width: CrispySpacing.sm),
              Text('Save to Device'),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'set_policy',
        child: Row(
          children: [
            Icon(Icons.delete_sweep_outlined, size: 20),
            SizedBox(width: CrispySpacing.sm),
            Text('Auto-Delete Policy'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 20),
            SizedBox(width: CrispySpacing.sm),
            Text('Delete'),
          ],
        ),
      ),
    ];
  }

  Future<void> _onMenuAction(
    String action,
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notifier = ref.read(dvrServiceProvider.notifier);
    switch (action) {
      case 'delete':
        await _confirmDelete(context, notifier);
      case 'play':
        await _triggerPlay(context, ref);
      case 'stop':
        notifier.stopRecording(recording.id);
      case 'upload':
        notifier.queueUpload(recording.id);
      case 'download':
        notifier.queueDownload(recording);
      // FE-DVR-12: Save to Device — stub, actual download needs platform integration.
      case 'save_to_device':
        _showSaveToDeviceSnackBar(context);
      case 'set_policy':
        await _setPolicy(context, notifier);
    }
  }

  /// FE-DVR-12: Shows a "Download started" snackbar.
  ///
  /// Actual file export requires platform-specific integration
  /// (e.g., share_plus or file_saver). This is a UI stub.
  void _showSaveToDeviceSnackBar(BuildContext context) {
    // FE-DVR-12
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download started: ${recording.programName}'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
      ),
    );
  }

  /// Shows a confirmation dialog before deleting a recording.
  Future<void> _confirmDelete(BuildContext context, DvrService notifier) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'Delete recording?',
      content: 'Delete "${recording.programName}"? This cannot be undone.',
    );
    if (confirmed) {
      notifier.removeRecording(recording.id);
    }
  }

  /// FE-DVR-03: Tap handler — play completed or in-progress recordings.
  ///
  /// Completed recordings play from the local [Recording.filePath].
  /// In-progress recordings play from the live [Recording.streamUrl]
  /// so users can watch while recording (resume-in-progress UX).
  void _onCardTap(BuildContext context, WidgetRef ref) {
    // FE-DVR-03
    if (recording.status == RecordingStatus.recording &&
        recording.streamUrl != null &&
        recording.streamUrl!.isNotEmpty) {
      // Navigate to player with the live stream URL directly.
      ref
          .read(playbackSessionProvider.notifier)
          .startPlayback(
            streamUrl: recording.streamUrl!,
            isLive: true,
            channelName: recording.programName,
            channelLogoUrl: recording.channelLogoUrl,
            currentProgram: recording.channelName,
          );
      return;
    }

    if (_isPlayable) {
      _triggerPlay(context, ref);
    } else {
      final label = switch (recording.status) {
        RecordingStatus.scheduled => 'Scheduled',
        RecordingStatus.recording => 'Recording',
        RecordingStatus.failed => 'Failed',
        RecordingStatus.completed => 'Completed',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label: ${recording.programName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Build size display — live progress for recording,
  /// static for completed.
  Widget _buildSizeDisplay(BuildContext context, WidgetRef ref) {
    // Watch live progress for in-progress recordings.
    final progressBytes = ref.watch(
      dvrServiceProvider.select((s) => s.value?.progressBytes[recording.id]),
    );

    if (recording.status == RecordingStatus.recording &&
        progressBytes != null) {
      return Text(
        formatBytes(progressBytes),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (recording.fileSizeBytes != null) {
      return Text(
        recording.fileSizeMB,
        style: Theme.of(context).textTheme.labelSmall,
      );
    }

    return const SizedBox.shrink();
  }

  /// Delegates play to [DvrService.playRecording] and shows a
  /// snackbar if playback cannot start (file missing or no path).
  Future<void> _triggerPlay(BuildContext context, WidgetRef ref) async {
    final started = await ref
        .read(dvrServiceProvider.notifier)
        .playRecording(recording);
    if (!started && context.mounted) {
      final msg =
          recording.filePath == null || recording.filePath!.isEmpty
              ? 'Recording not available for playback'
              : 'Recording file not found';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Opens [AutoDeletePolicyDialog] and applies the chosen policy.
  Future<void> _setPolicy(BuildContext context, DvrService notifier) async {
    final updated = await showAutoDeletePolicyDialog(
      context: context,
      recording: recording,
    );
    if (updated != null) {
      await notifier.updateAutoDeletePolicy(
        id: recording.id,
        policy: updated.autoDeletePolicy,
        keepEpisodeCount: updated.keepEpisodeCount,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════
//  Playable status icon with play overlay
// ═══════════════════════════════════════════════════════

/// Status icon for a recording, with a play overlay when
/// the recording is playable (completed or in-progress).
class _PlayableStatusIcon extends StatelessWidget {
  const _PlayableStatusIcon({
    required this.recording,
    required this.isPlayable,
  });

  final Recording recording;
  final bool isPlayable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseIcon = _statusIcon(context, recording.status);

    if (!isPlayable) return baseIcon;

    // Overlay a small play badge on the bottom-right of the
    // status icon to signal that tapping the card starts playback.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        Positioned(
          right: -6,
          bottom: -6,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow, size: 11, color: cs.onPrimary),
          ),
        ),
      ],
    );
  }

  Widget _statusIcon(BuildContext context, RecordingStatus status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case RecordingStatus.scheduled:
        return Icon(Icons.schedule, color: cs.primary);
      case RecordingStatus.recording:
        return Icon(Icons.fiber_manual_record, color: cs.error);
      case RecordingStatus.completed:
        return Icon(Icons.check_circle, color: cs.tertiary);
      case RecordingStatus.failed:
        return Icon(Icons.error, color: cs.error);
    }
  }
}

// ═══════════════════════════════════════════════════════
//  Playback progress bar
// ═══════════════════════════════════════════════════════

/// Thin progress bar shown at the bottom of a card when
/// a saved playback position exists for the recording.
class _PlaybackProgressBar extends StatelessWidget {
  const _PlaybackProgressBar({required this.progress});

  /// Progress value in [0.0, 1.0].
  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.md,
        0,
        CrispySpacing.md,
        CrispySpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CrispyRadius.xs),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: cs.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Cloud status badge
// ═══════════════════════════════════════════════════════

/// Badge showing cloud sync status for a [Recording]:
/// uploading/downloading progress, synced, or cloud-only.
class _CloudStatusBadge extends ConsumerWidget {
  const _CloudStatusBadge({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild only when the active/queued transfer for this
    // specific recording changes.
    final activeTransfer = ref.watch(
      transferServiceProvider.select(
        (async) =>
            async.value?.tasks
                .where(
                  (t) =>
                      t.recordingId == recording.id &&
                      (t.status == TransferStatus.active ||
                          t.status == TransferStatus.queued),
                )
                .firstOrNull,
      ),
    );

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (activeTransfer != null) {
      // Uploading/downloading.
      final icon =
          activeTransfer.direction == TransferDirection.upload
              ? Icons.cloud_upload
              : Icons.cloud_download;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.secondary),
          const SizedBox(width: CrispySpacing.xs),
          if (activeTransfer.progress > 0)
            Text(
              '${(activeTransfer.progress * 100).toInt()}%',
              style: tt.labelSmall?.copyWith(color: cs.secondary),
            ),
        ],
      );
    }

    if (recording.remoteBackendId != null && recording.filePath != null) {
      // Synced (both local and cloud).
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done, size: 14, color: cs.tertiary),
          const SizedBox(width: CrispySpacing.xs),
          Text('Synced', style: tt.labelSmall?.copyWith(color: cs.tertiary)),
        ],
      );
    }

    if (recording.remoteBackendId != null) {
      // Cloud only.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud, size: 14, color: cs.primary),
          const SizedBox(width: CrispySpacing.xs),
          Text('Cloud', style: tt.labelSmall?.copyWith(color: cs.primary)),
        ],
      );
    }

    // Local only.
    return const SizedBox.shrink();
  }
}

// ═══════════════════════════════════════════════════════
//  Auto-delete policy badge
// ═══════════════════════════════════════════════════════

/// Inline badge showing the [AutoDeletePolicy] for a [Recording].
///
/// Hidden when the policy is [AutoDeletePolicy.keepAll] (the
/// default) to avoid noise on simple recordings.
class _AutoDeleteBadge extends StatelessWidget {
  const _AutoDeleteBadge({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final policy = recording.autoDeletePolicy;
    if (policy == AutoDeletePolicy.keepAll) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final label = switch (policy) {
      AutoDeletePolicy.keepAll => '',
      AutoDeletePolicy.keepN => 'Keep ${recording.keepEpisodeCount}',
      AutoDeletePolicy.deleteAfterWatching => 'Del. after watch',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(policy.icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: CrispySpacing.xs),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Quality badge (FE-DVR-08)
// ═══════════════════════════════════════════════════════

/// Inline badge showing the recording quality tier derived
/// from the [RecordingProfile].
///
/// Hidden for [RecordingProfile.original] (auto/default) to
/// keep the card clean unless a specific quality was chosen.
class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.profile});

  final RecordingProfile profile;

  /// Map [RecordingProfile] → [RecordingQuality] for display.
  RecordingQuality get _quality => switch (profile) {
    RecordingProfile.original => RecordingQuality.auto,
    RecordingProfile.high => RecordingQuality.hd,
    RecordingProfile.medium => RecordingQuality.hd,
    RecordingProfile.low => RecordingQuality.sd,
  };

  @override
  Widget build(BuildContext context) {
    // Hide badge for the default auto quality to reduce visual noise.
    if (profile == RecordingProfile.original) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = _quality;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        q.shortLabel,
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
