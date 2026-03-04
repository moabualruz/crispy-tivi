import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/epg_providers.dart';
import 'epg_program_detail.dart';

// ── EPG program block constants ──────────────────────────────

/// Minimum rendered width of a program block (px).
const double _kBlockMinWidth = 40.0;

/// Maximum rendered width of a program block (px).
const double _kBlockMaxWidth = 2000.0;

/// Right margin gap between adjacent program blocks (px).
const double _kProgramBlockGap = 1.0;

/// Vertical padding inside a program block (px).
///
/// Intentionally tighter than [CrispySpacing.xs] (4 px) to
/// prevent text overflow in short blocks.
const double _kBlockVerticalPadding = 2.0;

/// Border width on a currently-live program block (px).
const double _kLiveBorderWidth = 1.5;

/// Border width on a normal (non-live) program block (px).
const double _kNormalBorderWidth = 1.0;

/// Minimum height of the live-progress bar (px).
const double _kProgressBarMinHeight = 2.0;

/// Size of the catch-up history icon (px).
const double _kCatchupIconSize = 12.0;

/// Size (width and height) of the recording indicator dot (px).
const double _kRecordingDotSize = 6.0;

/// Horizontal offset of the recording dot when the catch-up
/// icon is also visible (px).
const double _kRecordingDotCatchupOffset = 14.0;

/// Minimum block width (px) at which a programme thumbnail is shown.
const double _kThumbnailMinWidth = 120.0;

/// Alpha (0–255) for the genre tint overlay (≈12% opacity).
const int _kGenreTintAlpha = 30;

/// Returns a subtle genre tint colour for [category], or null if
/// the category is unrecognised.
///
/// Matching is case-insensitive.
Color? _genreTint(String? category) {
  if (category == null || category.isEmpty) return null;
  final lower = category.toLowerCase();
  if (lower.contains('sport')) return Colors.green.withAlpha(_kGenreTintAlpha);
  if (lower.contains('news')) return Colors.blue.withAlpha(_kGenreTintAlpha);
  if (lower.contains('movie') || lower.contains('film')) {
    return Colors.purple.withAlpha(_kGenreTintAlpha);
  }
  if (lower.contains('kid') || lower.contains('child')) {
    return Colors.orange.withAlpha(_kGenreTintAlpha);
  }
  if (lower.contains('music')) return Colors.pink.withAlpha(_kGenreTintAlpha);
  if (lower.contains('doc')) return Colors.teal.withAlpha(_kGenreTintAlpha);
  return null;
}

/// A single programme block in the EPG timeline.
///
/// Width is proportional to the programme duration.
/// Shows title + time, highlight if currently live,
/// dims past programs, and uses [FocusWrapper] for TV
/// navigation.
class EpgProgramBlock extends ConsumerWidget {
  const EpgProgramBlock({
    required this.entry,
    required this.pixelsPerMinute,
    this.onTap,
    this.isSelected = false,
    this.hasCatchup = false,
    this.isRecording = false,
    super.key,
  });

  final EpgEntry entry;
  final double pixelsPerMinute;
  final VoidCallback? onTap;
  final bool isSelected;

  /// Whether this programme's channel supports catch-up playback.
  final bool hasCatchup;

  /// Whether this programme is being recorded or scheduled.
  final bool isRecording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final crispyColors = Theme.of(context).crispyColors;

    final durationMinutes = entry.endTime.difference(entry.startTime).inMinutes;
    final blockWidth = (durationMinutes * pixelsPerMinute).clamp(
      _kBlockMinWidth,
      _kBlockMaxWidth,
    );

    final now = ref.watch(epgClockProvider)();
    final isLive = entry.isLiveAt(now);
    final isPast = entry.isPastAt(now);

    // Past programmes with catch-up are less dimmed than those without.
    final canCatchup = isPast && hasCatchup;
    final opacity = isPast ? (canCatchup ? 0.75 : 0.5) : 1.0;

    // Format start/end times for the accessibility label.
    final startHour = entry.startTime.hour.toString().padLeft(2, '0');
    final startMin = entry.startTime.minute.toString().padLeft(2, '0');
    final endHour = entry.endTime.hour.toString().padLeft(2, '0');
    final endMin = entry.endTime.minute.toString().padLeft(2, '0');
    final timeLabel = '$startHour:$startMin – $endHour:$endMin';

    // FE-EPG-04: genre tint (10–15% opacity overlay).
    final genreTint = _genreTint(entry.category);

    // FE-EPG-05: thumbnail only when block is wide enough.
    final showThumbnail =
        blockWidth > _kThumbnailMinWidth &&
        entry.iconUrl != null &&
        entry.iconUrl!.isNotEmpty;

    return FocusWrapper(
      onSelect: onTap ?? () => _showDetail(context, ref),
      borderRadius: CrispyRadius.none,
      semanticLabel: '${entry.title}, $timeLabel',
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: blockWidth,
          margin: const EdgeInsets.only(right: _kProgramBlockGap),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            color:
                isSelected
                    ? colorScheme.surfaceContainer
                    : isLive
                    ? crispyColors.liveRed.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainer,
            border: Border.all(
              color:
                  isLive
                      ? crispyColors.liveRed
                      : colorScheme.outline.withValues(alpha: 0.12),
              width: isLive ? _kLiveBorderWidth : _kNormalBorderWidth,
            ),
          ),
          // ClipRRect keeps the thumbnail within rounded-corner bounds if
          // a radius is ever applied; zero radius is a no-op here.
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // FE-EPG-05: background thumbnail for wide blocks.
                if (showThumbnail)
                  Positioned.fill(
                    child: Image.network(
                      entry.iconUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, st) => const SizedBox.shrink(),
                    ),
                  ),

                // FE-EPG-05: dark gradient to keep text readable.
                if (showThumbnail)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.black.withAlpha(200),
                            Colors.black.withAlpha(160),
                          ],
                        ),
                      ),
                    ),
                  ),

                // FE-EPG-04: genre colour tint overlay.
                if (genreTint != null)
                  Positioned.fill(child: ColoredBox(color: genreTint)),

                // Content (text + progress bar).
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.sm,
                    vertical: _kBlockVerticalPadding,
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.title,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight:
                                  isLive ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: CrispySpacing.xxs),
                          Text(
                            '${_formatTime(entry.startTime, ref)} – '
                            '${_formatTime(entry.endTime, ref)}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          // Progress bar for live programs.
                          if (isLive) ...[
                            const SizedBox(height: CrispySpacing.xs),
                            ClipRect(
                              child: LinearProgressIndicator(
                                value: entry.progressAt(now),
                                minHeight: _kProgressBarMinHeight,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  crispyColors.liveRed,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Catch-up badge for past programmes with archive available.
                      if (canCatchup)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            Icons.history,
                            size: _kCatchupIconSize,
                            color: colorScheme.primary,
                          ),
                        ),
                      // Recording indicator (red dot).
                      if (isRecording)
                        Positioned(
                          top: 0,
                          right: canCatchup ? _kRecordingDotCatchupOffset : 0,
                          child: Container(
                            width: _kRecordingDotSize,
                            height: _kRecordingDotSize,
                            decoration: BoxDecoration(
                              color: crispyColors.liveRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final timezone = ref.read(epgTimezoneProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(),
      builder: (_) => EpgProgramDetailSheet(entry: entry, timezone: timezone),
    );
  }

  String _formatTime(DateTime dt, WidgetRef ref) {
    final timezone = ref.watch(epgTimezoneProvider);
    return TimezoneUtils.formatTime(dt, timezone);
  }
}
