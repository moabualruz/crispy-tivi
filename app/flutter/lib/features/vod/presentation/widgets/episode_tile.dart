import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/episode_utils.dart' show formatEpisodeLabel;

// ── Thumbnail dimension constants (T12) ──────────────────────────────────────

/// Width of the episode thumbnail.
const double _kThumbnailWidth = 120.0;

/// Height of the episode thumbnail.
const double _kThumbnailHeight = 68.0;

/// Spacing between thumbnail and text content.
const double _kThumbnailSpacing = 12.0;

// ── Badge constants (T14) ─────────────────────────────────────────────────────

/// Horizontal padding inside the LAST WATCHED badge.
const double _kBadgePaddingH = 6.0;

/// Vertical padding inside the LAST WATCHED badge.
const double _kBadgePaddingV = 2.0;

/// Width of the accent left border on the up-next tile.
const double _kUpNextBorderWidth = 3.0;

/// A single episode row with optional progress
/// indicator and watched state.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
    this.onLongPress,
    this.onToggleWatched,
    this.progress,
    this.isLastWatched = false,
    this.isUpNext = false,
  });

  final VodItem episode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// FE-SRD-03: Callback to toggle the watched state.
  ///
  /// When provided, a checkmark icon button is shown on
  /// the trailing edge of the tile. Tapping it marks the
  /// episode as watched (progress = 100%) or unwatched
  /// (progress = 0%), depending on the current state.
  final VoidCallback? onToggleWatched;

  /// Watch progress (0.0 to 1.0).
  final double? progress;

  /// Whether this is the most recently watched
  /// episode.
  final bool isLastWatched;

  /// Whether this is the next episode to play
  /// (the episode immediately after [isLastWatched]).
  final bool isUpNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final subtitle = formatEpisodeLabel(
      episode.seasonNumber,
      episode.episodeNumber,
    );

    final isWatched = progress != null && progress! >= kCompletionThreshold;
    final isInProgress =
        progress != null && progress! > 0 && progress! < kCompletionThreshold;

    return FocusWrapper(
      onSelect: onTap,
      onLongPress: onLongPress,
      borderRadius: CrispyRadius.sm,
      scaleFactor: 1.03,
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border:
              isUpNext
                  ? Border(
                    left: BorderSide(
                      color: colorScheme.primary,
                      width: _kUpNextBorderWidth,
                    ),
                  )
                  : const Border(),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.xs,
          ),
          color:
              isLastWatched
                  ? colorScheme.tertiary.withValues(alpha: 0.08)
                  : isUpNext
                  ? colorScheme.primary.withValues(alpha: 0.06)
                  : null,
          child: Row(
            children: [
              _thumbnail(colorScheme, isWatched, isInProgress),
              const SizedBox(width: _kThumbnailSpacing),
              Expanded(
                child: _info(textTheme, colorScheme, subtitle, isWatched),
              ),
              // FE-SRD-03: Watched toggle icon button.
              if (onToggleWatched != null)
                IconButton(
                  tooltip: isWatched ? 'Mark as unwatched' : 'Mark as watched',
                  onPressed: onToggleWatched,
                  icon: Icon(
                    isWatched ? Icons.check_circle : Icons.check_circle_outline,
                    color:
                        isWatched
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              if (isUpNext)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline, color: colorScheme.primary),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _kBadgePaddingH,
                        vertical: _kBadgePaddingV,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(CrispyRadius.xs),
                      ),
                      child: Text(
                        'UP NEXT',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Icon(
                  isWatched ? Icons.replay : Icons.play_circle_outline,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(ColorScheme cs, bool isWatched, bool isInProgress) {
    return ClipRect(
      child: SizedBox(
        width: _kThumbnailWidth,
        height: _kThumbnailHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            episode.posterUrl != null && episode.posterUrl!.isNotEmpty
                ? SmartImage(
                  itemId: episode.id,
                  title: episode.name,
                  imageUrl: episode.posterUrl,
                  fit: BoxFit.cover,
                  memCacheHeight: _kThumbnailHeight.toInt(),
                  memCacheWidth: _kThumbnailWidth.toInt(),
                )
                : _placeholder(cs),
            if (isWatched)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(CrispySpacing.xs),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.rectangle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            if (isInProgress)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progress!,
                  backgroundColor: Colors.black45,
                  color: cs.primary,
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _info(TextTheme tt, ColorScheme cs, String subtitle, bool isWatched) {
    final showBadgeRow = subtitle.isNotEmpty || isLastWatched;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBadgeRow)
          Row(
            children: [
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (isLastWatched) ...[
                if (subtitle.isNotEmpty)
                  const SizedBox(width: CrispySpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kBadgePaddingH,
                    vertical: _kBadgePaddingV,
                  ),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withValues(alpha: 0.15),
                  ),
                  // T14: use textTheme token — labelSmall is the
                  // smallest semantic text style in Material 3.
                  child: Text(
                    'LAST WATCHED',
                    style: tt.labelSmall?.copyWith(
                      color: cs.tertiary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        Text(
          episode.name,
          style: tt.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Runtime chip (duration only).
        if (episode.duration != null)
          Text(
            '${episode.duration} min',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        // FE-SRD-05: Air date row — shown when year metadata is
        // available. VodItem has no full airDate field yet; `year`
        // is used as the best available proxy. When the domain
        // entity gains an `airDate: DateTime?` field, replace
        // `episode.year` with a formatted date:
        //   DateFormat('MMM d, y').format(episode.airDate!)
        if (episode.year != null)
          Text(
            'Aired ${episode.year}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        if (episode.description != null && episode.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: CrispySpacing.xs),
            child: Text(
              episode.description!,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 28),
      ),
    );
  }
}
