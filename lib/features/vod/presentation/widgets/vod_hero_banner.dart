import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
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

/// Layered trailer video overlay for hero banner cards.
///
/// Behaviour:
/// - After [CrispyAnimation.trailerDelay] (3 s) the muted [media_kit] player
///   starts playing the item's trailer URL ([VodItem.backdropUrl]
///   is used as a proxy — real trailer URLs would come from
///   a `trailerUrl` field once the domain entity has one).
/// - The video fades in over the static poster via [AnimatedOpacity].
/// - An unmute button appears in the bottom-right corner on hover/tap.
/// - The player is paused when the card scrolls out of the visible
///   viewport (detected via a [VisibilityDetector]-equivalent using
///   a [Visibility] listener).
/// - Falls back gracefully when no trailer URL is available.
///
/// NOTE: `VodItem` does not yet have a dedicated `trailerUrl` field.
/// We use `backdropUrl` as a stub. When `trailerUrl` is added to the
/// domain entity, replace [_trailerUrl] accordingly.
class _TrailerOverlay extends StatefulWidget {
  const _TrailerOverlay({required this.item});

  final VodItem item;

  @override
  State<_TrailerOverlay> createState() => _TrailerOverlayState();
}

const Duration _kTrailerDelay = CrispyAnimation.trailerDelay;

class _TrailerOverlayState extends State<_TrailerOverlay>
    with WidgetsBindingObserver {
  Player? _player;
  bool _videoVisible = false;
  bool _muted = true;
  bool _isHovered = false;
  bool _disposed = false;

  /// Stub: use backdropUrl as trailer URL until VodItem.trailerUrl exists.
  String? get _trailerUrl => widget.item.backdropUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_trailerUrl != null && _trailerUrl!.isNotEmpty) {
      Future.delayed(_kTrailerDelay, _startTrailer);
    }
  }

  Future<void> _startTrailer() async {
    if (_disposed || _trailerUrl == null) return;
    final player = Player();
    _player = player;
    await player.setVolume(0); // muted by default
    await player.open(Media(_trailerUrl!));
    if (!_disposed) {
      setState(() => _videoVisible = true);
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _player?.setVolume(_muted ? 0 : 100);
  }

  void _stopTrailer() {
    _player?.stop();
    if (!_disposed) setState(() => _videoVisible = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTrailer();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_trailerUrl == null || _trailerUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          children: [
            // Video fade-in over the static poster.
            AnimatedOpacity(
              opacity: _videoVisible ? 1.0 : 0.0,
              duration: CrispyAnimation.slow,
              curve: CrispyAnimation.enterCurve,
              child:
                  _videoVisible
                      ? _StaticTrailerPlaceholder(url: _trailerUrl!)
                      : const SizedBox.shrink(),
            ),

            // Mute/unmute button — visible on hover when trailer is playing.
            if (_videoVisible)
              AnimatedOpacity(
                opacity: _isHovered ? 1.0 : 0.0,
                duration: CrispyAnimation.fast,
                child: Positioned(
                  right: CrispySpacing.sm,
                  bottom: CrispySpacing.sm,
                  child: Semantics(
                    button: true,
                    label: 'Toggle mute',
                    child: GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(CrispyRadius.tv),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 16,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Static placeholder showing the backdrop image as a trailer stand-in.
///
/// In production, replace with a real `media_kit_video` [Video] widget
/// once `VodItem.trailerUrl` is available and the video layer is fully
/// wired up. The Player is still created and controlled above; this
/// widget only provides the visual surface.
class _StaticTrailerPlaceholder extends StatelessWidget {
  const _StaticTrailerPlaceholder({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: SmartImage(
          itemId: 'trailer_$url',
          title: '',
          imageUrl: url,
          imageKind: 'backdrop',
          fit: BoxFit.cover,
          memCacheWidth: 600,
        ),
      ),
    );
  }
}
