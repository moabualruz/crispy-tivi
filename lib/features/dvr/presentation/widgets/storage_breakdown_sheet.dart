import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../data/dvr_service.dart';
import '../../domain/entities/recording.dart';
import '../../domain/utils/dvr_payload.dart';
import '../../domain/utils/storage_breakdown.dart';
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
//  Presentation-layer icon mapping
// ─────────────────────────────────────────────────────────

/// Returns the icon for a [CategoryBreakdown] by its label.
///
/// Icons belong in the presentation layer; the domain model is
/// icon-free.
IconData _iconForCategory(String label) {
  switch (label) {
    case 'Completed':
      return Icons.check_circle_outline;
    case 'In Progress':
      return Icons.fiber_manual_record;
    case 'Scheduled':
      return Icons.schedule;
    case 'Failed':
      return Icons.error_outline;
    default:
      return Icons.folder_outlined;
  }
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
                  loading: () => const LoadingStateWidget(),
                  error: (err, _) => ErrorStateWidget(message: 'Error: $err'),
                  data: (state) {
                    return FutureBuilder<StorageBreakdownData>(
                      future: _computeBreakdown(ref, state.recordings),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LoadingStateWidget();
                        }
                        if (snapshot.hasError) {
                          return ErrorStateWidget(
                            message: 'Error: ${snapshot.error}',
                          );
                        }
                        final data = snapshot.data;
                        if (data == null) {
                          return const LoadingStateWidget();
                        }
                        return _BreakdownBody(
                          data: data,
                          scrollController: scrollController,
                          ref: ref,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  /// Calls [CrispyBackend.computeStorageBreakdown] and deserialises
  /// the result into [StorageBreakdownData].
  Future<StorageBreakdownData> _computeBreakdown(
    WidgetRef ref,
    List<Recording> recordings,
  ) async {
    final backend = ref.read(crispyBackendProvider);
    final recordingsJson = jsonEncode(recordings.map(recordingToMap).toList());
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final resultJson = await backend.computeStorageBreakdown(
      recordingsJson,
      nowMs,
    );
    final map = jsonDecode(resultJson) as Map<String, dynamic>;
    return StorageBreakdownData.fromJson(map);
  }
}

// ─────────────────────────────────────────────────────────
//  Breakdown body (extracted for cleaner FutureBuilder)
// ─────────────────────────────────────────────────────────

class _BreakdownBody extends StatelessWidget {
  const _BreakdownBody({
    required this.data,
    required this.scrollController,
    required this.ref,
  });

  final StorageBreakdownData data;
  final ScrollController scrollController;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
      children: [
        _TotalTile(data: data),
        const SizedBox(height: CrispySpacing.xs),
        // Storage bar
        if (data.totalBytes > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            child: StorageBar(totalBytes: data.totalBytes),
          ),
        const SizedBox(height: CrispySpacing.md),

        // By Status
        _SectionHeader(icon: Icons.bar_chart, label: 'BY STATUS'),
        for (final cat in data.categories)
          _CategoryTile(category: cat, totalBytes: data.totalBytes),

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
          _CleanUpSection(candidates: data.cleanUpCandidates, ref: ref),
        ],
        const SizedBox(height: CrispySpacing.xl),
      ],
    );
  }

  List<Widget> _buildChannelRows(StorageBreakdownData data) {
    // Sort by bytes descending.
    final entries =
        data.channelBytes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((e) {
      final count = data.channelCounts[e.key] ?? 0;
      final fraction = data.totalBytes > 0 ? e.value / data.totalBytes : 0.0;

      return _ChannelRow(
        channelName: e.key,
        mbLabel: formatBytes(e.value),
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

  final StorageBreakdownData data;

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

  final CategoryBreakdown category;
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
          Icon(
            _iconForCategory(category.label),
            size: 18,
            color: cs.onSurfaceVariant,
          ),
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

  final List<CleanUpCandidate> candidates;
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

  final CleanUpCandidate candidate;
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
