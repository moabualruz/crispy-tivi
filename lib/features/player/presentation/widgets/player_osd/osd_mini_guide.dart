import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/crispy_colors.dart';
import '../../../../../core/utils/date_format_utils.dart';
import '../../../../../core/utils/duration_formatter.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../epg/presentation/providers/epg_providers.dart';
import '../../../../iptv/domain/entities/epg_entry.dart';

/// Compact EPG programme strip for the OSD bottom area.
///
/// Shows the currently-airing programme and the next one
/// for the playing live TV channel.  Only rendered when
/// [isLive] is true and EPG data is available.
///
/// Layout (single row):
///   [progress bar] current title · time remaining  |  next ›  title  start time
///
/// Design notes:
///   • Two-column layout: current (flex 3) + next (flex 2)
///   • Red 2 px progress bar beneath the current title
///   • Greyed-out next programme with › chevron
///   • No background — sits inside the existing bottom-bar
///     gradient
class OsdMiniGuide extends ConsumerWidget {
  const OsdMiniGuide({
    required this.channelEpgId,
    required this.isLive,
    required this.textTheme,
    super.key,
  });

  /// EPG channel ID used to look up programme data.
  final String channelEpgId;

  /// Whether the current stream is live TV.
  /// Returns [SizedBox.shrink] when false.
  final bool isLive;

  /// Text theme passed down from the OSD to avoid
  /// redundant [Theme.of] lookups.
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLive) return const SizedBox.shrink();

    final epgState = ref.watch(epgProvider);
    final current = epgState.getNowPlaying(channelEpgId);
    if (current == null) return const SizedBox.shrink();

    final next = epgState.getNextProgram(channelEpgId);

    return Padding(
      padding: const EdgeInsets.only(bottom: CrispySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Current programme (flex 3) ──
          Expanded(
            flex: 3,
            child: _CurrentProgrammeCell(entry: current, textTheme: textTheme),
          ),

          // ── Next programme (flex 2) ──
          if (next != null) ...[
            const SizedBox(width: CrispySpacing.sm),
            Expanded(
              flex: 2,
              child: _NextProgrammeCell(entry: next, textTheme: textTheme),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Current programme cell
// ─────────────────────────────────────────────────────────────

class _CurrentProgrammeCell extends StatelessWidget {
  const _CurrentProgrammeCell({required this.entry, required this.textTheme});

  final EpgEntry entry;
  final TextTheme textTheme;

  /// Formats the time remaining until this programme ends.
  String _timeRemaining() {
    final remaining = entry.endTime.difference(DateTime.now().toUtc());
    if (remaining.isNegative) return '';
    return '${DurationFormatter.humanShort(remaining)} left';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + time remaining
        Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: CrispySpacing.xs),
            Text(
              _timeRemaining(),
              style: textTheme.labelSmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),

        const SizedBox(height: CrispySpacing.xxs),

        // Red progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(CrispyRadius.progressBar),
          child: SizedBox(
            height: 2,
            child: Stack(
              children: [
                Container(color: Colors.white.withValues(alpha: 0.2)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: entry.progress.clamp(0.0, 1.0),
                  child: Container(color: CrispyColors.netflixRed),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Next programme cell
// ─────────────────────────────────────────────────────────────

class _NextProgrammeCell extends StatelessWidget {
  const _NextProgrammeCell({required this.entry, required this.textTheme});

  final EpgEntry entry;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final dimColor = Colors.white.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.navigate_next_rounded, size: 14, color: dimColor),
            Expanded(
              child: Text(
                entry.title,
                style: textTheme.bodySmall?.copyWith(color: dimColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: CrispySpacing.xs),
            Text(
              formatH12mm(entry.startTime),
              style: textTheme.labelSmall?.copyWith(color: dimColor),
            ),
          ],
        ),
        // Spacer so the cell aligns with the progress bar below the current cell
        const SizedBox(height: CrispySpacing.xxs + 2),
      ],
    );
  }
}
