import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;

import '../../../../core/constants.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/hover_builder.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/data/watch_history_service.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_favorites_provider.dart';

/// A poster card for VOD items (movies / series).
///
/// Supports:
/// - Tap to open detail sheet (movie) or series
///   detail
/// - Long press to open context menu
/// - Hover-reveal star to toggle favorites
/// - Netflix-style hover preview after 300ms delay
class VodPosterCard extends ConsumerWidget {
  const VodPosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.heroTag,
    this.progress,
    this.isMovie, // Backward compatibility for previous callsites
    this.showRank = false,
    this.rank,
    this.rankFontSize,
    this.overlayBuilder,
    this.badge,
    this.autofocus = false,
  });

  final VodItem item;
  final VoidCallback? onTap;

  /// Called on long-press (context menu trigger).
  final VoidCallback? onLongPress;
  final String? heroTag;

  /// Backward compatibility flag.
  final bool? isMovie;

  /// Watch progress (0.0 to 1.0).
  final double? progress;

  /// Whether to display the rank number overlay.
  final bool showRank;

  /// Optional rank for top 10
  final int? rank;

  /// Font size for the rank number.
  final double? rankFontSize;

  /// Optional widget builder to display custom overlays (progress bars, badges) over the poster.
  final Widget Function(BuildContext, VodItem)? overlayBuilder;

  /// Optional status badge shown in the top-right corner of the poster.
  ///
  /// Use [ContentBadge] values to indicate new episodes, new seasons,
  /// active recordings, or expiring catchup content.
  final ContentBadge? badge;

  /// Whether this card should request focus on first build.
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final safeHeroTag = heroTag ?? item.id;
    final numberWidth =
        (showRank && rank != null)
            ? ((rankFontSize ?? 64.0) * (rank! >= 10 ? 1.0 : 0.7))
            : 0.0;

    return Semantics(
      label: item.name,
      button: true,
      hint: item.type == VodType.movie ? 'Movie' : 'Series',
      child: HoverBuilder(
        builder:
            (context, isHovered) => FocusWrapper(
              autofocus: autofocus,
              scaleFactor: CrispyAnimation.hoverScale,
              onSelect:
                  onTap ??
                  () {
                    if (item.type == VodType.movie) {
                      context.push(
                        AppRoutes.vodDetails,
                        extra: {'item': item, 'heroTag': safeHeroTag},
                      );
                    } else {
                      context.push(AppRoutes.seriesDetail, extra: item);
                    }
                  },
              onLongPress: onLongPress,
              borderRadius: CrispyRadius.tv,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          left: numberWidth,
                          child: ClipRect(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Hero(
                                  tag: safeHeroTag,
                                  child: SmartImage(
                                    itemId: item.id,
                                    title: item.name,
                                    imageUrl: item.posterUrl,
                                    imageKind: 'poster',
                                    icon:
                                        item.type == VodType.movie
                                            ? Icons.movie_outlined
                                            : Icons.tv,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                  ),
                                ),
                                // Rating badge (top-left).
                                if (item.rating != null &&
                                    item.rating!.isNotEmpty)
                                  Positioned(
                                    top: CrispySpacing.xs,
                                    left: CrispySpacing.xs,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: CrispySpacing.xs,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface.withValues(
                                          alpha: 0.87,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          CrispyRadius.tv,
                                        ),
                                        border: Border.all(
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                      child: Text(
                                        item.rating!,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (item.type == VodType.series &&
                                    item.seasonCount != null)
                                  Positioned(
                                    bottom: CrispySpacing.xs,
                                    left: CrispySpacing.xs,
                                    child: _SeasonCountBadge(
                                      seasonCount: item.seasonCount,
                                      colorScheme: colorScheme,
                                      textTheme: textTheme,
                                    ),
                                  ),
                                // FE-VOD-08: Watchlist quick-add bookmark
                                // button (top-right, actionable).
                                //
                                // Shows a filled bookmark when favorited,
                                // an "add" icon when not. On mobile it is
                                // always visible; on desktop/web it fades
                                // in on hover.
                                //
                                // Uses select() to rebuild only when THIS
                                // item's favorite status changes.
                                Positioned(
                                  top: CrispySpacing.xs,
                                  right: CrispySpacing.xs,
                                  child: _WatchlistButton(
                                    isFavorite: ref.watch(
                                      vodFavoritesProvider.select(
                                        (s) =>
                                            s.value?.contains(item.id) ?? false,
                                      ),
                                    ),
                                    isHovered: isHovered,
                                    onToggle:
                                        () => ref
                                            .read(vodFavoritesProvider.notifier)
                                            .toggleFavorite(item.id),
                                  ),
                                ),
                                // Content status badge (top-right, below
                                // the watchlist button which sits at
                                // top:4/right:4 with ~26px total height).
                                if (badge != null)
                                  Positioned(
                                    top: CrispySpacing.xs + 28,
                                    right: CrispySpacing.xs,
                                    child: ContentStatusBadge(badge: badge!),
                                  ),
                                if (progress != null && progress! > 0)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: LinearProgressIndicator(
                                      value: progress!,
                                      backgroundColor: colorScheme.surface
                                          .withValues(alpha: 0.45),
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                // FE-VOD-02: Completed-content checkmark
                                // badge (bottom-right).
                                //
                                // Shown when watch progress >= 95% threshold.
                                // Reads from [vodItemIsCompletedProvider] if
                                // the caller did not supply a [progress] prop,
                                // or derives it from the prop directly.
                                _CompletedBadge(
                                  itemId: item.id,
                                  progressProp: progress,
                                ),
                                if (overlayBuilder != null)
                                  overlayBuilder!(context, item),
                              ],
                            ),
                          ),
                        ),
                        if (showRank && rank != null)
                          Positioned(
                            bottom: 5,
                            left: 0,
                            child: _RankOverlay(
                              rank: rank!,
                              fontSize: rankFontSize ?? 64.0,
                              fillColor: colorScheme.surface,
                              strokeColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.sm),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

// ── FE-VOD-08: Watchlist bookmark button ─────────────

/// Circular glassmorphic button to toggle favorite / watchlist
/// status on a [VodPosterCard].
///
/// - Shows [Icons.bookmark_rounded] (filled) when [isFavorite].
/// - Shows [Icons.add_rounded] when not favorited.
/// - On desktop/web: fades in on hover (controlled by [isHovered]).
/// - On mobile: always visible (touch-first UX).
class _WatchlistButton extends StatelessWidget {
  const _WatchlistButton({
    required this.isFavorite,
    required this.isHovered,
    required this.onToggle,
  });

  final bool isFavorite;
  final bool isHovered;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // On mobile (no mouse) always show; on desktop reveal on hover.
    final alwaysVisible = MediaQuery.of(context).size.shortestSide < 600;
    final show = alwaysVisible || isFavorite || isHovered;

    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: CrispyAnimation.fast,
      child: Semantics(
        button: true,
        label: isFavorite ? 'Remove from watchlist' : 'Add to watchlist',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isFavorite ? Icons.bookmark_rounded : Icons.add_rounded,
              size: 16,
              color: isFavorite ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── FE-VOD-02: Completed checkmark badge ────────────

/// Circular badge shown in the bottom-right of a [VodPosterCard]
/// when the item has been watched to completion (>= 95%).
///
/// Uses [progressProp] when the caller already resolved progress
/// (avoids a second async lookup). Falls back to
/// [vodItemIsCompletedProvider] otherwise.
class _CompletedBadge extends ConsumerWidget {
  const _CompletedBadge({required this.itemId, this.progressProp});

  final String itemId;

  /// Raw 0.0-1.0 progress as passed by the parent, if available.
  final double? progressProp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fast path: caller already supplied progress.
    final fromProp =
        progressProp != null && progressProp! >= kCompletionThreshold;

    if (fromProp) {
      return _badge(context);
    }

    // Slow path: check watch history asynchronously.
    final isCompleted =
        ref.watch(vodItemIsCompletedProvider(itemId)).asData?.value ?? false;

    if (!isCompleted) {
      // Return a zero-size Positioned so StackFit.expand
      // does not stretch a plain SizedBox.shrink().
      return const Positioned(bottom: 0, right: 0, child: SizedBox.shrink());
    }
    return _badge(context);
  }

  Widget _badge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: CrispySpacing.xs,
      right: CrispySpacing.xs,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(Icons.check_rounded, size: 13, color: cs.onPrimary),
      ),
    );
  }
}

// ── Season count badge (FE-SR-07) ──────────────────

/// Compact badge showing the number of seasons for a series.
///
/// Renders only when [seasonCount] is non-null and > 0.
/// Position and style follow the design-system token rules
/// (secondaryContainer background, labelSmall text).
class _SeasonCountBadge extends StatelessWidget {
  const _SeasonCountBadge({
    required this.seasonCount,
    required this.colorScheme,
    required this.textTheme,
  });

  /// Number of seasons — null means "unknown / not shown".
  final int? seasonCount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (seasonCount == null || seasonCount! <= 0) {
      return const SizedBox.shrink();
    }
    final label = seasonCount == 1 ? '1 Season' : '$seasonCount Seasons';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Rank overlay ──────────────────────────────────

/// Renders a rank number with a solid fill and stroke outline
/// using a single [CustomPainter] pass, avoiding the two-Text
/// stacking anti-pattern.
class _RankOverlay extends StatelessWidget {
  const _RankOverlay({
    required this.rank,
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
  });

  final int rank;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RankPainter(
        rank: rank,
        fontSize: fontSize,
        fillColor: fillColor,
        strokeColor: strokeColor,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 0.85,
          color: Colors.transparent,
        ),
      ),
    );
  }
}

/// Paints a rank number with a filled body and a white stroke outline.
///
/// Uses two [canvas.drawParagraph] calls — stroke first, fill second —
/// so the outline sits behind the fill without leaking outside the glyph.
class _RankPainter extends CustomPainter {
  const _RankPainter({
    required this.rank,
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
  });

  final int rank;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;

  ui.Paragraph _buildParagraph(Color color, PaintingStyle style) {
    final paint =
        Paint()
          ..color = color
          ..style = style;
    if (style == PaintingStyle.stroke) {
      paint.strokeWidth = 3.0;
    }

    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              height: 0.85,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              foreground: paint,
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              height: 0.85,
            ),
          )
          ..addText('$rank');
    return builder.build()..layout(const ui.ParagraphConstraints(width: 200));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw stroke first so fill covers it.
    canvas.drawParagraph(
      _buildParagraph(strokeColor, PaintingStyle.stroke),
      Offset.zero,
    );
    canvas.drawParagraph(
      _buildParagraph(fillColor, PaintingStyle.fill),
      Offset.zero,
    );
  }

  @override
  bool shouldRepaint(_RankPainter old) =>
      old.rank != rank ||
      old.fontSize != fontSize ||
      old.fillColor != fillColor ||
      old.strokeColor != strokeColor;
}
