import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../../../core/utils/input_mode_notifier.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../providers/player_providers.dart';
import 'player_osd/osd_shared.dart';

/// Opacity of the strip when the OSD is hidden in TV
/// (non-touch) mode. Low so it doesn't distract during
/// viewing.
const _kTvPersistOpacity = 0.55;

/// EPG program info strip shown above the OSD bottom bar
/// during live TV playback.
///
/// Shows:
///   • Current programme title and time range with a
///     red progress bar beneath it.
///   • Next programme title (greyed out).
///
/// Behaviour:
///   • Only rendered when [isLive] is true.
///   • On TV/keyboard/gamepad input it persists at
///     [_kTvPersistOpacity] when the OSD is hidden; on
///     touch/mouse devices it appears only when the OSD
///     is visible.
class LiveEpgStrip extends ConsumerWidget {
  const LiveEpgStrip({
    required this.channelEpgId,
    required this.isLive,
    super.key,
  });

  /// EPG channel ID used to look up programme data.
  final String channelEpgId;

  /// Whether the current stream is live. When false the
  /// strip renders nothing.
  final bool isLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLive) return const SizedBox.shrink();

    final osdVisible = ref.watch(osdVisibleProvider);
    final inputMode = ref.watch(inputModeProvider);
    final isTv =
        inputMode == InputMode.keyboard || inputMode == InputMode.gamepad;

    // Opacity: always visible on TV (dim when OSD hidden),
    // fully visible when OSD is up, hidden otherwise.
    final double opacity;
    if (osdVisible) {
      opacity = 1.0;
    } else if (isTv) {
      opacity = _kTvPersistOpacity;
    } else {
      opacity = 0.0;
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: kOsdBottomBarHeight,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: CrispyAnimation.normal,
        child: _EpgStripContent(channelEpgId: channelEpgId),
      ),
    );
  }
}

/// Internal content widget that reads EPG data and
/// renders current + next programme rows.
class _EpgStripContent extends ConsumerWidget {
  const _EpgStripContent({required this.channelEpgId});

  final String channelEpgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epgState = ref.watch(epgProvider);
    final textTheme = Theme.of(context).textTheme;

    final current = epgState.getNowPlaying(channelEpgId);
    if (current == null) return const SizedBox.shrink();

    final next = epgState.getNextProgram(channelEpgId);
    final timeRange =
        '${formatH12mm(current.startTime)}'
        ' – '
        '${formatH12mm(current.endTime)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.md,
        CrispySpacing.sm,
        CrispySpacing.md,
        CrispySpacing.sm,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0x99000000), // 60% black
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current programme row
          _ProgrammeRow(
            entry: current,
            timeRange: timeRange,
            textTheme: textTheme,
            isCurrent: true,
          ),
          // Progress bar
          const SizedBox(height: CrispySpacing.xs),
          _EpgProgressBar(progress: current.progress),

          // Next programme row
          if (next != null) ...[
            const SizedBox(height: CrispySpacing.xs),
            _ProgrammeRow(
              entry: next,
              timeRange:
                  '${formatH12mm(next.startTime)}'
                  ' – '
                  '${formatH12mm(next.endTime)}',
              textTheme: textTheme,
              isCurrent: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgrammeRow extends StatelessWidget {
  const _ProgrammeRow({
    required this.entry,
    required this.timeRange,
    required this.textTheme,
    required this.isCurrent,
  });

  final EpgEntry entry;
  final String timeRange;
  final TextTheme textTheme;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.55);
    final timeColor = Colors.white.withValues(alpha: 0.55);

    return Row(
      children: [
        if (!isCurrent)
          Padding(
            padding: const EdgeInsets.only(right: CrispySpacing.xs),
            child: Icon(
              Icons.navigate_next_rounded,
              size: 14,
              color: timeColor,
            ),
          ),
        Expanded(
          child: Text(
            entry.title,
            style: textTheme.bodySmall?.copyWith(
              color: titleColor,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: CrispySpacing.sm),
        Text(
          timeRange,
          style: textTheme.labelSmall?.copyWith(color: timeColor),
        ),
      ],
    );
  }
}

class _EpgProgressBar extends StatelessWidget {
  const _EpgProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CrispyRadius.progressBar),
      child: SizedBox(
        height: 2,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.2)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(color: CrispyColors.netflixRed),
            ),
          ],
        ),
      ),
    );
  }
}
