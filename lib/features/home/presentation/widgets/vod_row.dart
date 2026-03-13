import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/input_mode_notifier.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../../../core/widgets/nav_arrow.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../../vod/presentation/widgets/vod_poster_card.dart';

// Card widths per layout class (uses project Breakpoints thresholds).
const _kW = {
  LayoutClass.compact: 120.0,
  LayoutClass.medium: 140.0,
  LayoutClass.expanded: 160.0,
  LayoutClass.large: 180.0,
};

// Rank-number font sizes per layout class.
const _kF = {
  LayoutClass.compact: 64.0,
  LayoutClass.medium: 80.0,
  LayoutClass.expanded: 100.0,
  LayoutClass.large: 120.0,
};

/// Generic horizontal VOD row with optional rank overlays.
///
/// Card sizing uses [LayoutClass] from [Breakpoints]:
///   compact (<600dp)→120dp, medium→140dp, expanded→160dp, large→180dp.
class VodRow extends ConsumerStatefulWidget {
  const VodRow({
    super.key,
    this.title,
    this.icon,
    required this.items,
    this.isTitleBadge = false,
    this.showRank = false,
    this.cardWidth,
    this.cardHeight,
    this.sectionHeight,
    this.itemSpacing = CrispySpacing.sm,
    this.arrowWidth = 48.0,
    this.arrowIconSize = 32.0,
    this.customOnTap,
    this.overlayBuilder,
    this.badgeBuilder,
    this.onSeeAll,
  });

  final String? title;
  final IconData? icon;
  final List<VodItem> items;
  final bool isTitleBadge;
  final bool showRank;
  final double? cardWidth;
  final double? cardHeight;
  final double? sectionHeight;
  final double itemSpacing;
  final double arrowWidth;
  final double arrowIconSize;
  final void Function(BuildContext, VodItem, String)? customOnTap;
  final Widget Function(BuildContext, VodItem)? overlayBuilder;

  /// Optional callback returning a [ContentBadge] for a given item.
  ///
  /// When non-null the returned badge is passed to [VodPosterCard.badge].
  /// Use this to surface "NEW EP", "NEW SEASON", or other status pills.
  final ContentBadge? Function(VodItem)? badgeBuilder;

  /// Optional callback invoked when the "See all" link is tapped.
  /// When non-null, a "See all ›" text button appears in the header.
  final VoidCallback? onSeeAll;

  @override
  ConsumerState<VodRow> createState() => _VodRowState();
}

class _VodRowState extends ConsumerState<VodRow> {
  final _sc = ScrollController();
  bool _hovered = false;

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _scroll(double delta) {
    final target = (_sc.offset + delta).clamp(
      0.0,
      _sc.position.maxScrollExtent,
    );
    _sc.animateTo(
      target,
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
    );
  }

  void _tap(BuildContext ctx, VodItem item, String tag) {
    if (item.type == VodType.movie) {
      ctx.push(AppRoutes.vodDetails, extra: {'item': item, 'heroTag': tag});
    } else {
      ctx.push(AppRoutes.seriesDetail, extra: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layoutClass;
    final cardW = widget.cardWidth ?? _kW[layout]!;
    final rankFont = _kF[layout]!;
    final cardH = widget.cardHeight ?? (cardW * 1.5);
    final hoverPad = (cardH * CrispyAnimation.hoverScale) - cardH;
    final vertPad = CrispySpacing.md + hoverPad;
    final sectionH = widget.sectionHeight ?? (cardH + (vertPad * 2) + 45);
    final inputMode = ref.watch(inputModeProvider);
    final showArrows =
        _hovered || InputModeNotifier.showFocusIndicators(inputMode);
    final items =
        widget.showRank ? widget.items.take(10).toList() : widget.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(
                left: CrispySpacing.md,
                right: CrispySpacing.md,
                top: CrispySpacing.xl,
                bottom: CrispySpacing.xs,
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon!,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: CrispySpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      widget.title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.onSeeAll != null)
                    TextButton(
                      onPressed: widget.onSeeAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CrispySpacing.sm,
                        ),
                        minimumSize: Size.zero,
                        // Audited: inline "See all" text button in row header;
                        // padding provides adequate touch area.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'See all \u203a',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: SizedBox(
            height: sectionH,
            child: Stack(
              children: [
                ClipRect(
                  child: ListView.builder(
                    controller: _sc,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                      vertical: vertPad,
                    ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      final rank = widget.showRank ? i + 1 : null;
                      final tag = '${item.id}_home_${widget.title ?? 'row'}_$i';
                      final numW =
                          widget.showRank
                              ? (rankFont * ((rank ?? 0) >= 10 ? 1.0 : 0.7))
                              : 0.0;
                      return Padding(
                        key: ValueKey(item.id),
                        padding: EdgeInsets.only(right: widget.itemSpacing),
                        child: SizedBox(
                          width: numW + cardW,
                          height: cardH,
                          child: VodPosterCard(
                            item: item,
                            heroTag: tag,
                            onTap:
                                widget.customOnTap != null
                                    ? () => widget.customOnTap!(ctx, item, tag)
                                    : () => _tap(ctx, item, tag),
                            onLongPress:
                                () => showVodRowContextMenu(
                                  context: ctx,
                                  ref: ref,
                                  item: item,
                                ),
                            showRank: widget.showRank,
                            rank: rank,
                            rankFontSize: rankFont,
                            overlayBuilder: widget.overlayBuilder,
                            badge: widget.badgeBuilder?.call(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (showArrows)
                  Positioned(
                    left: 0,
                    top: vertPad,
                    bottom: vertPad,
                    width: widget.arrowWidth,
                    child: NavArrow(
                      icon: Icons.chevron_left,
                      onTap: () => _scroll(-(cardW * 3)),
                      isLeft: true,
                      iconSize: widget.arrowIconSize,
                    ),
                  ),
                if (showArrows)
                  Positioned(
                    right: 0,
                    top: vertPad,
                    bottom: vertPad,
                    width: widget.arrowWidth,
                    child: NavArrow(
                      icon: Icons.chevron_right,
                      onTap: () => _scroll(cardW * 3),
                      isLeft: false,
                      iconSize: widget.arrowIconSize,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the long-press context menu for a [VodItem] in [VodRow].
void showVodRowContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required VodItem item,
}) {
  showContextMenuPanel(
    context: context,
    sections:
        item.type == VodType.movie
            ? buildMovieContextMenu(
              context: context,
              movieName: item.name,
              isFavorite: item.isFavorite,
              colorScheme: Theme.of(context).colorScheme,
              onToggleFavorite:
                  () => ref.read(vodProvider.notifier).toggleFavorite(item.id),
              onPlay:
                  () => ref
                      .read(playbackSessionProvider.notifier)
                      .startPlayback(
                        streamUrl: item.streamUrl,
                        isLive: false,
                        channelName: item.name,
                        channelLogoUrl: item.posterUrl,
                        posterUrl: item.posterUrl,
                        mediaType: 'movie',
                      ),
              onCopyUrl: () => copyStreamUrl(context, item.streamUrl),
              onOpenExternal:
                  hasExternalPlayer(ref)
                      ? () => openInExternalPlayer(
                        context: context,
                        ref: ref,
                        streamUrl: item.streamUrl,
                        title: item.name,
                      )
                      : null,
            )
            : buildSeriesContextMenu(
              context: context,
              seriesName: item.name,
              isFavorite: item.isFavorite,
              colorScheme: Theme.of(context).colorScheme,
              onToggleFavorite:
                  () => ref.read(vodProvider.notifier).toggleFavorite(item.id),
            ),
  );
}
