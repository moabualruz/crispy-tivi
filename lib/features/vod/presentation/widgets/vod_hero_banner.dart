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

/// Trailer overlay placeholder for hero banner cards.
///
/// Currently shows a fade-in backdrop image after a delay.
/// When `VodItem.trailerUrl` is added to the domain entity,
/// this should wire up a `Video` widget via [CrispyPlayer].
/// No raw `Player()` instances are created — only [CrispyPlayer]
/// should be used for media playback.
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

    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: CrispyAnimation.slow,
        curve: CrispyAnimation.enterCurve,
        child:
            _visible
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  child: SmartImage(
                    itemId: 'trailer_$_backdropUrl',
                    title: '',
                    imageUrl: _backdropUrl!,
                    imageKind: 'backdrop',
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                  ),
                )
                : const SizedBox.shrink(),
      ),
    );
  }
}
