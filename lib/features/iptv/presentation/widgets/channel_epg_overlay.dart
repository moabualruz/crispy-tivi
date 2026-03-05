import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entry.dart';

/// Semi-transparent EPG info overlay for the channel
/// video preview.
///
/// Shows channel name, LIVE badge, program title, time
/// range, progress bar, and up to two upcoming programmes
/// over a dark gradient.
///
/// TV-T21: `Colors.white` is intentional here — this widget renders
/// directly over a video surface, which is always a dark image frame.
/// The design system's `colorScheme.onSurface` would not guarantee
/// sufficient contrast on video content, so a fixed white (#FFFFFF) is
/// used for text/icon legibility at all times.
class ChannelEpgOverlay extends StatelessWidget {
  const ChannelEpgOverlay({
    required this.channel,
    this.entry,
    this.upcomingPrograms = const [],
    super.key,
  });

  final Channel channel;
  final EpgEntry? entry;

  /// Up to 2 upcoming programmes shown below the current
  /// programme in the TV preview panel.
  final List<EpgEntry> upcomingPrograms;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final crispyColors = Theme.of(context).crispyColors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            colorScheme.surface.withValues(alpha: 0.87),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.md,
        CrispySpacing.lg,
        CrispySpacing.md,
        CrispySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Channel name + LIVE badge
          Row(
            children: [
              Expanded(
                child: Text(
                  channel.name,
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entry != null && entry!.isLive) ...[
                const SizedBox(width: CrispySpacing.sm),
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
              ],
            ],
          ),

          if (entry != null) ...[
            const SizedBox(height: CrispySpacing.xxs),
            // Program title
            Text(
              entry!.title,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CrispySpacing.xxs),
            // Time range
            Text(
              '${formatHHmmLocal(entry!.startTime)}'
              ' – ${formatHHmmLocal(entry!.endTime)}',
              style: textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            // Progress bar
            if (entry!.isLive) ...[
              const SizedBox(height: CrispySpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(CrispyRadius.tvSm),
                child: LinearProgressIndicator(
                  value: entry!.progress,
                  minHeight: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    crispyColors.liveRed,
                  ),
                ),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: CrispySpacing.xxs),
              child: Text(
                'No programme info',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          // Upcoming programmes (TV preview panel only)
          if (upcomingPrograms.isNotEmpty) ...[
            const SizedBox(height: CrispySpacing.xs),
            for (final up in upcomingPrograms)
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.xxs),
                child: Row(
                  children: [
                    Text(
                      formatHHmmLocal(up.startTime),
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: CrispySpacing.xs),
                    Expanded(
                      child: Text(
                        up.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
