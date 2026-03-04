import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../data/dvr_service.dart';
import '../../domain/entities/recording.dart';
import 'storage_bar.dart';

// ─────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────

/// Shows the storage breakdown bottom sheet.
void showStorageBreakdownSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: CrispyRadius.top(CrispyRadius.md),
    ),
    builder: (_) => const StorageBreakdownSheet(),
  );
}

// ─────────────────────────────────────────────────────────
//  Storage breakdown data helpers
// ─────────────────────────────────────────────────────────

/// Per-category storage summary.
class _CategoryBreakdown {
  const _CategoryBreakdown({
    required this.label,
    required this.count,
    required this.bytes,
    required this.icon,
  });

  final String label;
  final int count;
  final int bytes;
  final IconData icon;

  double get mb => bytes / (1024 * 1024);

  String get mbLabel => '${mb.toStringAsFixed(1)} MB';
}

/// Recordings recommended for clean-up.
class _CleanUpCandidate {
  const _CleanUpCandidate({required this.recording, required this.reason});

  final Recording recording;
  final String reason;
}

/// Computes storage breakdown from a list of recordings.
_StorageBreakdownData _computeBreakdown(List<Recording> recordings) {
  final completed =
      recordings.where((r) => r.status == RecordingStatus.completed).toList();
  final scheduled =
      recordings.where((r) => r.status == RecordingStatus.scheduled).toList();
  final inProgress =
      recordings.where((r) => r.status == RecordingStatus.recording).toList();
  final failed =
      recordings.where((r) => r.status == RecordingStatus.failed).toList();

  int bytesFor(List<Recording> recs) =>
      recs.fold(0, (sum, r) => sum + (r.fileSizeBytes ?? 0));

  // Build per-channel breakdown from completed recordings.
  final channelBytes = <String, int>{};
  final channelCounts = <String, int>{};
  for (final r in completed) {
    channelBytes[r.channelName] =
        (channelBytes[r.channelName] ?? 0) + (r.fileSizeBytes ?? 0);
    channelCounts[r.channelName] = (channelCounts[r.channelName] ?? 0) + 1;
  }

  final categories = [
    _CategoryBreakdown(
      label: 'Completed',
      count: completed.length,
      bytes: bytesFor(completed),
      icon: Icons.check_circle_outline,
    ),
    if (inProgress.isNotEmpty)
      _CategoryBreakdown(
        label: 'In Progress',
        count: inProgress.length,
        bytes: bytesFor(inProgress),
        icon: Icons.fiber_manual_record,
      ),
    if (scheduled.isNotEmpty)
      _CategoryBreakdown(
        label: 'Scheduled',
        count: scheduled.length,
        bytes: 0,
        icon: Icons.schedule,
      ),
    if (failed.isNotEmpty)
      _CategoryBreakdown(
        label: 'Failed',
        count: failed.length,
        bytes: bytesFor(failed),
        icon: Icons.error_outline,
      ),
  ];

  // Clean-up candidates: old completed recordings (>30 days) with
  // deleteAfterWatching policy or failed recordings.
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final cleanUpCandidates = <_CleanUpCandidate>[
    for (final r in completed)
      if (r.endTime.isBefore(cutoff))
        _CleanUpCandidate(recording: r, reason: 'Recorded over 30 days ago'),
    for (final r in failed)
      _CleanUpCandidate(recording: r, reason: 'Failed recording'),
  ];

  return _StorageBreakdownData(
    totalBytes: bytesFor(recordings),
    totalCount: recordings.length,
    categories: categories,
    channelBytes: channelBytes,
    channelCounts: channelCounts,
    cleanUpCandidates: cleanUpCandidates.take(10).toList(), // cap at 10
  );
}

class _StorageBreakdownData {
  const _StorageBreakdownData({
    required this.totalBytes,
    required this.totalCount,
    required this.categories,
    required this.channelBytes,
    required this.channelCounts,
    required this.cleanUpCandidates,
  });

  final int totalBytes;
  final int totalCount;
  final List<_CategoryBreakdown> categories;
  final Map<String, int> channelBytes;
  final Map<String, int> channelCounts;
  final List<_CleanUpCandidate> cleanUpCandidates;

  double get totalMB => totalBytes / (1024 * 1024);

  String get totalMBLabel => '${totalMB.toStringAsFixed(1)} MB';
}

// ─────────────────────────────────────────────────────────
//  Sheet widget
// ─────────────────────────────────────────────────────────

/// DraggableScrollableSheet showing storage breakdown for all
/// DVR recordings, grouped by category and channel, with a
/// clean-up section for old/failed recordings.
class StorageBreakdownSheet extends ConsumerWidget {
  const StorageBreakdownSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dvrServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder:
          (context, scrollController) => Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.sm),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(CrispyRadius.full),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.storage, size: 20, color: cs.primary),
                    const SizedBox(width: CrispySpacing.sm),
                    Text('Storage Breakdown', style: tt.titleMedium),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body
              Expanded(
                child: stateAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (state) {
                    final data = _computeBreakdown(state.recordings);
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: CrispySpacing.sm,
                      ),
                      children: [
                        _TotalTile(data: data),
                        const SizedBox(height: CrispySpacing.xs),
                        // Storage bar
                        if (data.totalBytes > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CrispySpacing.md,
                            ),
                            child: StorageBar(totalBytes: data.totalBytes),
                          ),
                        const SizedBox(height: CrispySpacing.md),

                        // By Status
                        _SectionHeader(
                          icon: Icons.bar_chart,
                          label: 'BY STATUS',
                        ),
                        for (final cat in data.categories)
                          _CategoryTile(
                            category: cat,
                            totalBytes: data.totalBytes,
                          ),

                        // By Channel
                        if (data.channelBytes.isNotEmpty) ...[
                          const SizedBox(height: CrispySpacing.md),
                          _SectionHeader(icon: Icons.tv, label: 'BY CHANNEL'),
                          ..._buildChannelRows(data),
                        ],

                        // Clean up
                        if (data.cleanUpCandidates.isNotEmpty) ...[
                          const SizedBox(height: CrispySpacing.md),
                          _SectionHeader(
                            icon: Icons.cleaning_services_outlined,
                            label: 'CLEAN UP',
                          ),
                          _CleanUpSection(
                            candidates: data.cleanUpCandidates,
                            ref: ref,
                          ),
                        ],
                        const SizedBox(height: CrispySpacing.xl),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  List<Widget> _buildChannelRows(_StorageBreakdownData data) {
    // Sort by bytes descending.
    final entries =
        data.channelBytes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((e) {
      final mb = e.value / (1024 * 1024);
      final count = data.channelCounts[e.key] ?? 0;
      final fraction = data.totalBytes > 0 ? e.value / data.totalBytes : 0.0;

      return _ChannelRow(
        channelName: e.key,
        mbLabel: '${mb.toStringAsFixed(1)} MB',
        count: count,
        fraction: fraction,
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.data});

  final _StorageBreakdownData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.totalMBLabel,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                Text(
                  '${data.totalCount} recording${data.totalCount == 1 ? '' : 's'} total',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.storage, size: 36, color: cs.primaryContainer),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.totalBytes});

  final _CategoryBreakdown category;
  final int totalBytes;

  double get _fraction =>
      totalBytes > 0 && category.bytes > 0
          ? (category.bytes / totalBytes).clamp(0.0, 1.0)
          : 0.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      child: Row(
        children: [
          Icon(category.icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category.label, style: tt.bodyMedium),
                    Text(
                      category.bytes > 0
                          ? category.mbLabel
                          : '${category.count} item${category.count == 1 ? '' : 's'}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                if (_fraction > 0) ...[
                  const SizedBox(height: CrispySpacing.xxs),
                  LinearProgressIndicator(
                    value: _fraction,
                    minHeight: 3,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.secondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channelName,
    required this.mbLabel,
    required this.count,
    required this.fraction,
  });

  final String channelName;
  final String mbLabel;
  final int count;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      child: Row(
        children: [
          const Icon(Icons.tv_outlined, size: 16),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        channelName,
                        style: tt.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$mbLabel · $count rec${count == 1 ? '' : 's'}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CrispySpacing.xxs),
                LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(cs.tertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Clean-up section
// ─────────────────────────────────────────────────────────

class _CleanUpSection extends StatelessWidget {
  const _CleanUpSection({required this.candidates, required this.ref});

  final List<_CleanUpCandidate> candidates;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.xs,
          ),
          child: Text(
            'These recordings may be safe to delete:',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        for (final candidate in candidates)
          _CleanUpTile(candidate: candidate, ref: ref),
      ],
    );
  }
}

class _CleanUpTile extends StatelessWidget {
  const _CleanUpTile({required this.candidate, required this.ref});

  final _CleanUpCandidate candidate;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rec = candidate.recording;

    return ListTile(
      dense: true,
      leading: Icon(Icons.delete_sweep_outlined, size: 18, color: cs.error),
      title: Text(
        rec.programName,
        style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${rec.channelName} · ${candidate.reason}',
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: cs.error,
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
        ),
        onPressed: () => _delete(context),
        child: const Text('Delete'),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Recording'),
            content: Text(
              'Delete "${candidate.recording.programName}"? '
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref
          .read(dvrServiceProvider.notifier)
          .removeRecording(candidate.recording.id);
    }
  }
}
