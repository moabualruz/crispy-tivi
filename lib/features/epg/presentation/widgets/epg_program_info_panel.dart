import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';

/// Persistent program info panel at top-right of EPG.
///
/// Shows details of the currently selected/focused
/// EPG entry: title, time range, progress bar,
/// description, action buttons.
class EpgProgramInfoPanel extends StatelessWidget {
  const EpgProgramInfoPanel({
    required this.entry,
    required this.channels,
    required this.timezone,
    this.onWatch,
    this.onRecord,
    super.key,
  });

  final EpgEntry? entry;
  final List<Channel> channels;
  final String timezone;
  final VoidCallback? onWatch;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (entry == null) {
      return Container(
        color: colorScheme.surface,
        padding: const EdgeInsets.all(CrispySpacing.md),
        alignment: Alignment.center,
        child: Text(
          'Select a program to see details',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final e = entry!;
    final isLive = e.isLive;
    final crispyColors = Theme.of(context).crispyColors;

    // Resolve channel name
    final channel =
        channels
            .where((c) => c.id == e.channelId || c.tvgId == e.channelId)
            .firstOrNull;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.all(CrispySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──
          Row(
            children: [
              if (isLive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  color: crispyColors.liveRed,
                  child: Text(
                    'LIVE',
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
              ],
              Expanded(
                child: Text(
                  e.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.xs),

          // ── Channel name ──
          if (channel != null)
            Text(
              channel.name,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          const SizedBox(height: CrispySpacing.xs),

          // ── Time range + duration ──
          Text(
            '${TimezoneUtils.formatTime(e.startTime, timezone)}'
            ' – ${TimezoneUtils.formatTime(e.endTime, timezone)}'
            '  (${e.duration.inMinutes} min)',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          // ── Progress bar (live only) ──
          if (isLive) ...[
            const SizedBox(height: CrispySpacing.xs),
            ClipRect(
              child: LinearProgressIndicator(
                value: e.progress,
                minHeight: 3,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(crispyColors.liveRed),
              ),
            ),
          ],

          // ── Description ──
          if (e.description != null && e.description!.isNotEmpty) ...[
            const SizedBox(height: CrispySpacing.xs),
            Expanded(
              child: Text(
                e.description!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),

          // ── Action buttons ──
          Row(
            children: [
              if (isLive)
                FilledButton.icon(
                  onPressed: onWatch,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Watch'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.sm,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              if (isLive) const SizedBox(width: CrispySpacing.sm),
              OutlinedButton.icon(
                onPressed: onRecord,
                icon: const Icon(Icons.fiber_manual_record, size: 14),
                label: const Text('Record'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.sm,
                  ),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
