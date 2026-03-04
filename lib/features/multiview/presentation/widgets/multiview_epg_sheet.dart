/// EPG mini-guide overlay for Multi-View — FE-MV-05.
///
/// A [DraggableScrollableSheet] listing current + next programme
/// for every active slot, sourced from the already-loaded
/// [epgProvider] data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../domain/entities/active_stream.dart';

// ─────────────────────────────────────────────────────────────
//  Public entry point
// ─────────────────────────────────────────────────────────────

/// Shows the multi-view EPG mini-guide as a [DraggableScrollableSheet].
///
/// [slots] is the ordered list of active streams (nulls for empty slots).
void showMultiViewEpgSheet(BuildContext context, List<ActiveStream?> slots) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MultiViewEpgSheet(slots: slots),
  );
}

// ─────────────────────────────────────────────────────────────
//  MultiViewEpgSheet
// ─────────────────────────────────────────────────────────────

/// Draggable bottom sheet that shows compact EPG info per active slot.
///
/// Each row displays:
/// - Slot number
/// - Channel name
/// - Current programme title
/// - Next programme title
class MultiViewEpgSheet extends ConsumerWidget {
  const MultiViewEpgSheet({super.key, required this.slots});

  final List<ActiveStream?> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Read the already-loaded EPG state — no fetch triggered here.
    final epgState = ref.watch(epgProvider);

    // Collect only filled slots with their original index.
    final activeSlots = <(int, ActiveStream)>[];
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s != null) activeSlots.add((i, s));
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.45, 0.85],
      builder: (context, scrollController) {
        return AnimatedContainer(
          duration: CrispyAnimation.fast,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: CrispyRadius.top(CrispyRadius.tv),
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(Icons.tv, size: 18, color: colorScheme.primary),
                    const SizedBox(width: CrispySpacing.xs),
                    Text(
                      'Now & Next',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${activeSlots.length} active',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Slot rows ──
              Expanded(
                child:
                    activeSlots.isEmpty
                        ? Center(
                          child: Text(
                            'No active slots',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            vertical: CrispySpacing.xs,
                          ),
                          itemCount: activeSlots.length,
                          separatorBuilder:
                              (context, index) => const Divider(
                                height: 1,
                                indent: CrispySpacing.md,
                                endIndent: CrispySpacing.md,
                              ),
                          itemBuilder: (context, listIndex) {
                            final (slotIndex, stream) = activeSlots[listIndex];
                            // Look up EPG by channel name (best-effort).
                            final now = epgState.getNowPlaying(
                              stream.channelName,
                            );
                            final next = epgState.getNextProgram(
                              stream.channelName,
                            );
                            return _EpgSlotRow(
                              slotNumber: slotIndex + 1,
                              channelName: stream.channelName,
                              nowTitle: now?.title,
                              nextTitle: next?.title,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _EpgSlotRow
// ─────────────────────────────────────────────────────────────

/// A single row in the EPG mini-guide.
///
/// Shows slot number badge, channel name, current programme
/// and next programme.
class _EpgSlotRow extends StatelessWidget {
  const _EpgSlotRow({
    required this.slotNumber,
    required this.channelName,
    required this.nowTitle,
    required this.nextTitle,
    required this.colorScheme,
    required this.textTheme,
  });

  final int slotNumber;
  final String channelName;
  final String? nowTitle;
  final String? nextTitle;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot number badge.
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
            ),
            alignment: Alignment.center,
            child: Text(
              '$slotNumber',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: CrispySpacing.sm),

          // Channel name + programmes.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel name.
                Text(
                  channelName,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: CrispySpacing.xxs),

                // Now.
                _ProgramLine(
                  label: 'NOW',
                  title: nowTitle ?? '—',
                  labelColor: colorScheme.primary,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: CrispySpacing.xxs),

                // Next.
                _ProgramLine(
                  label: 'NEXT',
                  title: nextTitle ?? '—',
                  labelColor: colorScheme.onSurfaceVariant,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _ProgramLine
// ─────────────────────────────────────────────────────────────

/// Inline label + programme title row.
class _ProgramLine extends StatelessWidget {
  const _ProgramLine({
    required this.label,
    required this.title,
    required this.labelColor,
    required this.textTheme,
    required this.colorScheme,
  });

  final String label;
  final String title;
  final Color labelColor;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: CrispySpacing.xs),
        Expanded(
          child: Text(
            title,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
