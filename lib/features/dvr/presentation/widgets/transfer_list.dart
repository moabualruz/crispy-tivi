import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../data/transfer_service.dart';
import '../../domain/entities/transfer_task.dart';

/// Tab content showing queued, active, and completed
/// cloud transfer tasks.
class TransferList extends ConsumerWidget {
  /// Creates the transfer list tab.
  const TransferList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferServiceProvider);

    return transferState.when(
      loading: () => const LoadingStateWidget(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (state) {
        final tasks = state.tasks;

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: CrispySpacing.sm),
                const Text('No transfers'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(CrispySpacing.md),
          itemCount: tasks.length,
          itemBuilder: (_, index) {
            final task = tasks[index];
            return _TransferCard(task: task);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Transfer card
// ═══════════════════════════════════════════════════════

class _TransferCard extends ConsumerWidget {
  const _TransferCard({required this.task});

  final TransferTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.direction == TransferDirection.upload
                      ? Icons.cloud_upload
                      : Icons.cloud_download,
                  color: cs.primary,
                ),
                const SizedBox(width: CrispySpacing.sm),
                Expanded(
                  child: Text(
                    task.recordingId ?? 'Unknown Recording',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusChip(task.status, cs, Theme.of(context).textTheme),
              ],
            ),

            // Progress bar for active transfers.
            if (task.status == TransferStatus.active)
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.sm),
                child: LinearProgressIndicator(
                  value: task.progress > 0 ? task.progress : null,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),

            if (task.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.xs),
                child: Text(
                  task.errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Actions row.
            if (!task.isDone)
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (task.status == TransferStatus.active)
                      TextButton(
                        onPressed:
                            () => ref
                                .read(transferServiceProvider.notifier)
                                .pauseTransfer(task.id),
                        child: const Text('Pause'),
                      ),
                    if (task.status == TransferStatus.paused)
                      TextButton(
                        onPressed:
                            () => ref
                                .read(transferServiceProvider.notifier)
                                .resumeTransfer(task.id),
                        child: const Text('Resume'),
                      ),
                    TextButton(
                      onPressed:
                          () => ref
                              .read(transferServiceProvider.notifier)
                              .cancelTransfer(task.id),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(TransferStatus status, ColorScheme cs, TextTheme tt) {
    final (label, color) = switch (status) {
      TransferStatus.queued => ('Queued', cs.outline),
      TransferStatus.active => ('Active', cs.primary),
      TransferStatus.paused => ('Paused', cs.tertiary),
      TransferStatus.completed => ('Done', cs.primary),
      TransferStatus.failed => ('Failed', cs.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
