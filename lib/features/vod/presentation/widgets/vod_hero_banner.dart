import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../domain/entities/vod_item.dart';

// FE-H-02: Animated hero with auto-playing muted trailer.

/// Hero banner wrapper providing a scaled-up manual scrolling
/// row of featured VOD items without auto-advancing.
/// This now defers rendering logic completely to [VodRow].
class VodHeroBanner extends ConsumerStatefulWidget {
  const VodHeroBanner({super.key, required this.items});

  final List<VodItem> items;

  @override
  ConsumerState<VodHeroBanner> createState() => _VodHeroBannerState();
}

class _VodHeroBannerState extends ConsumerState<VodHeroBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preCachePosterImages(widget.items);
    });
  }

  @override
  void didUpdateWidget(VodHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _preCachePosterImages(widget.items);
    }
  }

  void _preCachePosterImages(List<VodItem> items) {
    final toCache = items.take(6);
    for (final item in toCache) {
      final url = item.posterUrl;
      if (url != null && url.isNotEmpty) {
        // Use ResizeImage(width: 200) to match VodPosterCard's
        // memCacheWidth: 200 — same cache key means no network
        // re-fetch when the card renders.
        precacheImage(
          ResizeImage(NetworkImage(url), width: 200),
          context,
          onError: (e, st) {},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final w = MediaQuery.sizeOf(context).width;

    // Dimensions scaled roughly 2.5x to create ~6.25x larger area
    final cardW =
        w >= Breakpoints.expanded
            ? 450.0
            : (w >= Breakpoints.medium ? 400.0 : 350.0);
    // Explicit 2:3 portrait aspect ratio matching VodRow default
    final cardH = cardW * 1.5;

    // Add padding space for hover scale (approx 8%) and arbitrary bottom padding
    final hoverScale = CrispyAnimation.hoverScale;
    final hoverPadding = (cardH * hoverScale) - cardH;
    final sectionH = cardH + (CrispySpacing.md * 2) + hoverPadding + 45;

    return Padding(
      padding: EdgeInsets.zero,
      child: VodRow(
        title: null, // Omits the header entirely
        items: widget.items,
        cardWidth: cardW,
        cardHeight: cardH,
        sectionHeight: sectionH,
        itemSpacing: CrispySpacing.md,
        arrowWidth: 56.0,
        arrowIconSize: 40.0,
        // FE-H-02: custom card builder with trailer overlay
        overlayBuilder: (ctx, item) => _TrailerOverlay(item: item),
      ),
    );
  }
}

// ── FE-H-02: Trailer overlay on hero card ──────────────

/// Hero banner overlay that fades in a backdrop image with an info
/// scrim showing description, genre chip, and year badge.
///
/// The backdrop appears after [CrispyAnimation.trailerDelay] with
/// a bottom gradient scrim for readability. The overlay is purely
/// visual — all pointer events pass through to the card underneath.
class _TrailerOverlay extends StatefulWidget {
  const _TrailerOverlay({required this.item});

  final VodItem item;

  @override
  State<_TrailerOverlay> createState() => _TrailerOverlayState();
}

class _TrailerOverlayState extends State<_TrailerOverlay> {
  bool _visible = false;

  String? get _backdropUrl => widget.item.backdropUrl;

  @override
  void initState() {
    super.initState();
    if (_backdropUrl != null && _backdropUrl!.isNotEmpty) {
      Future.delayed(CrispyAnimation.trailerDelay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_backdropUrl == null || _backdropUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final item = widget.item;
    final textTheme = Theme.of(context).textTheme;
    final hasDescription =
        item.description != null && item.description!.isNotEmpty;
    final hasCategory = item.category != null && item.category!.isNotEmpty;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: CrispyAnimation.slow,
          curve: CrispyAnimation.enterCurve,
          child:
              _visible
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Backdrop image
                        SmartImage(
                          itemId: 'trailer_$_backdropUrl',
                          title: '',
                          imageUrl: _backdropUrl!,
                          imageKind: 'backdrop',
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                        ),
                        // Gradient scrim for text readability
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.35, 1.0],
                              colors: [Colors.transparent, Color(0xCC000000)],
                            ),
                          ),
                        ),
                        // Info overlay at bottom
                        if (hasDescription || hasCategory || item.year != null)
                          Positioned(
                            left: CrispySpacing.sm,
                            right: CrispySpacing.sm,
                            bottom: CrispySpacing.sm,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasDescription) ...[
                                  Text(
                                    item.description!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: CrispySpacing.xs),
                                ],
                                // Category + year chips row
                                Wrap(
                                  spacing: CrispySpacing.xs,
                                  runSpacing: CrispySpacing.xxs,
                                  children: [
                                    if (hasCategory)
                                      _HeroChip(label: item.category!),
                                    if (item.year != null)
                                      _HeroChip(label: '${item.year}'),
                                    if (item.rating != null)
                                      _HeroChip(label: item.rating!),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Compact translucent chip for hero banner info overlays.
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(CrispyRadius.xs),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
