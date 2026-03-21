import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/presentation/providers/player_providers.dart';

/// Horizontal channel section with
/// navigation arrows on hover.
///
/// Delegates carousel scaffolding (scroll controller, hover arrows,
/// header row) to [HorizontalScrollRow]. The Channel-specific card
/// layout (logo + label + tap/long-press) is provided via [itemBuilder].
///
/// When [epgData] is provided, each card shows a subtle overlay with
/// the current programme title and a thin progress bar at the bottom.
class ChannelListSection extends ConsumerWidget {
  const ChannelListSection({
    super.key,
    required this.title,
    required this.icon,
    required this.channels,
    this.onChannelLongPress,
    this.onSeeAll,
    this.badgeBuilder,
    this.epgData,
  });

  final String title;
  final IconData icon;
  final List<Channel> channels;

  /// Called with the channel on long-press.
  final void Function(Channel channel)? onChannelLongPress;

  /// Optional callback invoked when the "See all" link is tapped.
  /// When non-null, a "See all ›" text button appears in the header.
  final VoidCallback? onSeeAll;

  /// Optional callback that returns a [ContentBadge] for a given channel.
  ///
  /// When non-null and the callback returns a non-null value, a
  /// [ContentStatusBadge] pill is overlaid on the channel card's
  /// top-right corner. Use this to indicate recordings or expiring
  /// catchup availability.
  final ContentBadge? Function(Channel channel)? badgeBuilder;

  /// Optional EPG data keyed by channel EPG ID (tvgId or channel id).
  ///
  /// When provided, each channel tile shows the currently-airing
  /// programme title and a thin progress bar at the bottom.
  /// Gracefully ignored when null or when no matching entry exists.
  final Map<String, EpgEntry>? epgData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (channels.isEmpty) {
      return const SizedBox.shrink();
    }

    return HorizontalScrollRow<Channel>(
      items: channels,
      itemWidth: 140,
      sectionHeight: 140,
      headerIcon: icon,
      headerTitle: title,
      itemSpacing: CrispySpacing.xs,
      headerTrailing:
          onSeeAll != null
              ? TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  // Audited: inline "See all" text button in section header;
                  // padding provides adequate touch area.
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all \u203a',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
              : null,
      itemBuilder: (ctx, channel, _) {
        final channelBadge =
            badgeBuilder != null ? badgeBuilder!(channel) : null;
        // Resolve EPG entry: prefer tvgId, fall back to channel id.
        final epgKey = channel.tvgId ?? channel.id;
        final nowPlaying = epgData?[epgKey];

        return FocusWrapper(
          focusStyle: FocusIndicatorStyle.card,
          onSelect: () {
            ref
                .read(playbackSessionProvider.notifier)
                .startPlayback(
                  streamUrl: channel.streamUrl,
                  isLive: true,
                  channelName: channel.name,
                  channelLogoUrl: channel.logoUrl,
                  sourceId: channel.sourceId,
                );
          },
          onLongPress:
              onChannelLongPress != null
                  ? () => onChannelLongPress!(channel)
                  : null,
          borderRadius: CrispyRadius.tv,
          scaleFactor: CrispyAnimation.hoverScale,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SmartImage(
                        itemId: channel.id,
                        title: channel.name,
                        imageUrl: channel.logoUrl,
                        imageKind: 'logo',
                        fit: BoxFit.contain,
                        icon: Icons.tv,
                        placeholderAspectRatio: 140 / 100,
                        memCacheWidth: 280,
                      ),
                      // Content status badge (top-right).
                      if (channelBadge != null)
                        Positioned(
                          top: CrispySpacing.xs,
                          right: CrispySpacing.xs,
                          child: ContentStatusBadge(badge: channelBadge),
                        ),
                      // EPG overlay: programme title + progress bar.
                      if (nowPlaying != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _EpgOverlay(entry: nowPlaying),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CrispySpacing.xs),
              Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── EPG programme overlay ───────────────────────────────

/// Subtle bottom overlay on a channel tile showing the
/// currently-airing programme title and a thin progress bar.
///
/// Uses a dark scrim so text stays legible over any logo.
/// Kept minimal to avoid obscuring the channel artwork.
class _EpgOverlay extends StatelessWidget {
  const _EpgOverlay({required this.entry});

  final EpgEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = entry.progress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scrim + title label.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.72),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CrispySpacing.xs,
              CrispySpacing.sm,
              CrispySpacing.xs,
              CrispySpacing.xxs,
            ),
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 9,
              ),
            ),
          ),
        ),
        // Thin progress bar.
        LinearProgressIndicator(
          value: progress,
          minHeight: CrispySpacing.xxs,
          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
        ),
      ],
    );
  }
}
