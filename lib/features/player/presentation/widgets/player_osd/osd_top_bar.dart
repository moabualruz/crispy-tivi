import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/navigation/app_routes.dart';
import '../../../../../core/theme/crispy_colors.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/utils/date_format_utils.dart';
import '../../../../../core/widgets/live_badge.dart';
import '../../../../../core/widgets/smart_image.dart';
import '../../../../iptv/presentation/providers/channel_epg_provider.dart';
import '../../../domain/entities/playback_state.dart';
import 'format_badge_row.dart';
import 'osd_profile_switcher.dart';
import 'osd_shared.dart';
import 'osd_sleep_timer.dart';

/// Top bar: gradient overlay, back button + title.
///
/// Gradient top-to-transparent, minimal
/// controls. Removed: search, channels, recordings,
/// favorite star, AirPlay/Cast, LIVE badge (moved to
/// overflow or kept as badge).
class OsdTopBar extends StatelessWidget {
  const OsdTopBar({
    required this.channelName,
    required this.channelLogoUrl,
    required this.isLive,
    required this.colorScheme,
    required this.textTheme,
    this.channelEpgId,
    this.sleepTimerRemaining,
    this.videoFormat,
    this.audioFormat,
    this.is4k = false,
    this.onBack,
    super.key,
  });

  final String? channelName;
  final String? channelLogoUrl;
  final String? channelEpgId;
  final bool isLive;

  /// Remaining time on the sleep timer, or `null`
  /// if inactive.
  final Duration? sleepTimerRemaining;

  /// Video format badge (HDR10, Dolby Vision, etc.).
  final VideoFormat? videoFormat;

  /// Audio format badge (Atmos, DTS, etc.).
  final AudioFormat? audioFormat;

  /// Whether the stream is 4 K resolution.
  final bool is4k;

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: osdTopGradient),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + CrispySpacing.sm,
        left: CrispySpacing.md,
        right: CrispySpacing.md,
        bottom: CrispySpacing.xl,
      ),
      child: FocusTraversalGroup(
        child: Row(
          children: [
            // Back button (left arrow, white, 24px)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              tooltip: context.l10n.commonClose,
              onPressed:
                  onBack ??
                  () {
                    if (GoRouter.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.home);
                    }
                  },
            ),
            const SizedBox(width: CrispySpacing.sm),

            // Channel logo (small)
            if (channelLogoUrl != null && channelLogoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.sm),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: SmartImage(
                    title: channelName ?? '',
                    imageUrl: channelLogoUrl,
                    imageKind: 'logo',
                    fit: BoxFit.contain,
                    memCacheWidth: 56,
                    memCacheHeight: 56,
                  ),
                ),
              ),

            // Title + current program
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    channelName ?? '',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Current EPG program (live only)
                  if (isLive && channelEpgId != null)
                    CurrentProgramLabel(
                      channelEpgId: channelEpgId!,
                      textTheme: textTheme,
                    ),
                ],
              ),
            ),

            // FE-PM-12: Profile avatar / switcher button.
            // Only rendered when multiple profiles exist (handled
            // inside OsdProfileSwitcher).
            const Padding(
              padding: EdgeInsets.only(left: CrispySpacing.sm),
              child: OsdProfileSwitcher(),
            ),

            // Format badges (4K, HDR10, Dolby Vision, Atmos…)
            Padding(
              padding: const EdgeInsets.only(left: CrispySpacing.sm),
              child: FormatBadgeRow(
                colorScheme: colorScheme,
                is4k: is4k,
                videoFormat: videoFormat,
                audioFormat: audioFormat,
              ),
            ),

            // Sleep timer countdown badge
            if (sleepTimerRemaining != null &&
                sleepTimerRemaining! > Duration.zero)
              Padding(
                padding: const EdgeInsets.only(left: CrispySpacing.sm),
                child: SleepTimerBadge(
                  remaining: sleepTimerRemaining!,
                  colorScheme: colorScheme,
                ),
              ),

            // LIVE badge
            if (isLive)
              const Padding(
                padding: EdgeInsets.only(left: CrispySpacing.sm),
                child: LiveBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Displays the currently airing EPG program for a
/// channel.
///
/// Shows the program title, time range, and a progress
/// bar indicating how far into the program we are.
/// Gracefully returns an empty widget when no EPG data
/// is available.
class CurrentProgramLabel extends ConsumerWidget {
  const CurrentProgramLabel({
    required this.channelEpgId,
    required this.textTheme,
    super.key,
  });

  /// Channel ID used to look up EPG entries.
  final String channelEpgId;

  /// Text theme for styling labels.
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use best-of-breed EPG: on-demand (fresher) with batch
    // XMLTV fallback via the unified helper.
    final nowEntry = bestNowPlayingById(ref, channelEpgId);

    if (nowEntry == null || !nowEntry.isLive) {
      return const SizedBox.shrink();
    }

    final current = (
      title: nowEntry.title,
      startTime: nowEntry.startTime,
      endTime: nowEntry.endTime,
      progress: nowEntry.progress,
    );

    final timeRange =
        '${formatH12mm(current.startTime)}'
        ' - '
        '${formatH12mm(current.endTime)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                current.title,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Text(
              timeRange,
              style: textTheme.labelSmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: CrispySpacing.xs),
        // Progress bar showing how far into
        // the program
        SizedBox(
          height: 2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(CrispyRadius.tvSm),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: current.progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: CrispyColors.brandRed,
                        borderRadius: BorderRadius.circular(CrispyRadius.tvSm),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
