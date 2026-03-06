import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_typography.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/utils/watch_history_vod_adapter.dart';

export '../../domain/utils/watch_history_vod_adapter.dart'
    show WatchHistoryToVod;

/// Extra vertical space (px) added to the 16:9 card height to
/// accommodate the section header and bottom padding in
/// [ContinueWatchingSection] and [CrossDeviceSection].
const double kWatchHistorySectionPadding = 60.0;

/// Returns the card width for watch-history rows based on [screenWidth].
///
/// Breakpoints mirror the 16:9 landscape card sizing used by
/// [ContinueWatchingSection] and [CrossDeviceSection].
double watchHistoryCardWidth(double screenWidth) {
  if (screenWidth >= 1920) return 320.0;
  if (screenWidth >= 1280) return 280.0;
  if (screenWidth >= 960) return 240.0;
  return 200.0;
}

/// Shared overlay for watch-history card rows (continue watching, cross-device).
///
/// Renders inside a [Stack] that already contains the poster image.
/// Provides: a centered play icon, an optional dismiss button (top-right),
/// a progress bar at the bottom, and an optional [badge] widget.
///
/// This widget is intended for use as the return value of [VodRow.overlayBuilder],
/// which places it above the poster image inside [VodPosterCard].
class WatchHistoryCardOverlay extends StatelessWidget {
  const WatchHistoryCardOverlay({
    super.key,
    this.onDismiss,
    required this.progress,
    required this.progressColor,
    this.progressMinHeight = 4.0,
    this.badge,
  });

  /// Called when the user taps the dismiss (×) button.
  /// If null, the dismiss button is not rendered.
  final VoidCallback? onDismiss;

  /// Playback progress in the range [0.0, 1.0].
  final double progress;

  /// Color used for the progress bar fill.
  final Color progressColor;

  /// Height of the progress bar in logical pixels.
  final double progressMinHeight;

  /// Optional badge widget positioned over the card, e.g. a subtitle
  /// chip or a device-name pill.  Must be a [Positioned] widget so it
  /// can sit inside the surrounding [Stack].
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Play icon
        Center(
          child: Icon(
            Icons.play_circle_filled,
            size: 36,
            color: cs.onSurface.withValues(alpha: 200 / 255),
          ),
        ),
        // Dismiss button (×)
        if (onDismiss != null)
          Positioned(
            top: CrispySpacing.xs,
            right: CrispySpacing.xs,
            child: FocusWrapper(
              onSelect: onDismiss,
              borderRadius: 24.0,
              child: Container(
                decoration: BoxDecoration(
                  color: CrispyColors.vignetteEnd,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(CrispySpacing.xs),
                child: Icon(Icons.close, size: 16, color: cs.onSurface),
              ),
            ),
          ),
        // Progress bar
        if (progress > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: CrispyColors.vignetteStart,
              color: progressColor,
              minHeight: progressMinHeight,
            ),
          ),
        // Optional badge (subtitle chip, device pill, etc.)
        if (badge != null) badge!,
      ],
    );
  }
}

/// Netflix-style "Continue Watching" row utilizing standard [VodRow].
class ContinueWatchingSection extends ConsumerWidget {
  const ContinueWatchingSection({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.onSeeAll,
  });

  final String title;
  final IconData icon;
  final List<WatchHistoryEntry> items;

  /// Optional callback invoked when the "See all" link is tapped.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final vodItems = items.map((e) => e.toVodItem()).toList();

    // Calculate 16:9 landscape dimensions based on screen width
    final w = MediaQuery.sizeOf(context).width;
    final cardW = watchHistoryCardWidth(w);
    final cardH = cardW * 9 / 16;
    final sectionH =
        cardH + (CrispySpacing.md * 2) + kWatchHistorySectionPadding;

    return VodRow(
      title: title,
      icon: icon,
      items: vodItems,
      cardWidth: cardW,
      cardHeight: cardH,
      sectionHeight: sectionH,
      onSeeAll: onSeeAll,
      // Provide custom tap action to inject startPosition
      customOnTap: (ctx, vodItem, heroTag) {
        final item = items.firstWhereOrNull((e) => e.id == vodItem.id);
        if (item == null) return;
        ref
            .read(playbackSessionProvider.notifier)
            .startPlayback(
              streamUrl: item.streamUrl,
              channelName: item.name,
              isLive: false,
              startPosition: Duration(milliseconds: item.positionMs),
              posterUrl: item.posterUrl,
              seriesPosterUrl: item.seriesPosterUrl,
              mediaType: item.mediaType,
              seriesId: item.seriesId,
              seasonNumber: item.seasonNumber,
              episodeNumber: item.episodeNumber,
            );
      },
      // Build the progress bar and dismiss button
      overlayBuilder: (ctx, vodItem) {
        final item = items.firstWhereOrNull((e) => e.id == vodItem.id);
        if (item == null) return const SizedBox.shrink();
        final progress = item.progress;

        // Build the bottom-left info badge.
        // For series episodes: show "S2 E5" chip + "Xm left" chip.
        // For movies: show "Xm left" chip only.
        final episodeLabel = item.episodeLabel;
        final hasRemaining =
            item.durationMs > 0 && item.positionMs < item.durationMs;
        final hasBadge = episodeLabel != null || hasRemaining;

        Widget? badge;
        if (hasBadge) {
          final remainMs = item.durationMs - item.positionMs;
          final remainMin = hasRemaining ? (remainMs / 60000).ceil() : null;

          badge = Positioned(
            bottom: CrispySpacing.xs,
            left: CrispySpacing.xs,
            child: _EpisodeInfoBadge(
              episodeLabel: episodeLabel,
              remainingMinutes: remainMin,
              ctx: ctx,
            ),
          );
        }

        return WatchHistoryCardOverlay(
          onDismiss:
              () => ref.read(watchHistoryServiceProvider).delete(item.id),
          progress: progress,
          progressColor: Theme.of(ctx).colorScheme.primary,
          progressMinHeight: 4.0,
          badge: badge,
        );
      },
    );
  }
}

// ── Episode info badge ─────────────────────────────────────────────

/// Bottom-left badge overlay for continue-watching cards.
///
/// Shows two pill chips stacked vertically:
///   1. Episode label  — "S2 E5" (series only, when [episodeLabel] != null)
///   2. Remaining time — "12m left" (when [remainingMinutes] != null)
///
/// Both chips share the same semi-transparent dark background so
/// they read cleanly over any poster art without hardcoded colours.
class _EpisodeInfoBadge extends StatelessWidget {
  const _EpisodeInfoBadge({
    required this.ctx,
    this.episodeLabel,
    this.remainingMinutes,
  });

  /// The [BuildContext] from the overlay builder (used for theming).
  final BuildContext ctx;

  /// "S2 E5" label for series episodes; null for movies.
  final String? episodeLabel;

  /// Minutes remaining; null when duration is unknown.
  final int? remainingMinutes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(ctx).textTheme;
    final cs = Theme.of(ctx).colorScheme;

    final chips = <Widget>[];

    if (episodeLabel != null) {
      chips.add(
        _InfoChip(
          label: episodeLabel!,
          background: cs.primaryContainer.withValues(alpha: 0.88),
          foreground: cs.onPrimaryContainer,
          textTheme: textTheme,
          bold: true,
        ),
      );
    }

    if (remainingMinutes != null) {
      chips.add(
        _InfoChip(
          label: '${remainingMinutes}m left',
          background: CrispyColors.vignetteEnd,
          foreground: cs.onSurface,
          textTheme: textTheme,
          bold: false,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          chips[i],
          if (i < chips.length - 1) const SizedBox(height: CrispySpacing.xxs),
        ],
      ],
    );
  }
}

/// A single pill chip used inside [_EpisodeInfoBadge].
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.textTheme,
    required this.bold,
  });

  final String label;
  final Color background;
  final Color foreground;
  final TextTheme textTheme;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CrispySpacing.xxs),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontSize: CrispyTypography.micro,
          color: foreground,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}
