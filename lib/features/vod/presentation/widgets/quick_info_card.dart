import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/vod_item.dart';

// FE-VODS-05: Quick Info Card on focus/hover (TV UX).

/// Dwell duration before the Quick Info Card is shown on TV (D-pad focus).
const Duration _kTvDwellDelay = Duration(milliseconds: 800);

/// Mixin that wires up the Quick Info Card trigger logic.
///
/// Apply to any [StatefulWidget] that wraps a VOD poster card.
/// The mixin tracks D-pad focus dwell (TV) and long-press (mobile).
///
/// Usage:
/// ```dart
/// class _MyCardState extends State<MyCard>
///     with QuickInfoCardMixin<MyCard> {
///   @override
///   VodItem get vodItem => widget.item;
/// }
/// ```
mixin QuickInfoCardMixin<T extends StatefulWidget> on State<T> {
  /// The [VodItem] this card represents.
  VodItem get vodItem;

  OverlayEntry? _overlayEntry;
  Timer? _dwellTimer;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _dwellTimer = Timer(_kTvDwellDelay, () {
        if (mounted && _focusNode.hasFocus) _showCard();
      });
    } else {
      _dwellTimer?.cancel();
      _removeCard();
    }
  }

  void _showCard() {
    if (_overlayEntry != null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenH = MediaQuery.of(context).size.height;

    // Position above if near the bottom, below otherwise.
    final positionAbove = offset.dy + size.height > screenH * 0.6;

    _overlayEntry = OverlayEntry(
      builder:
          (ctx) => _QuickInfoOverlay(
            item: vodItem,
            targetOffset: offset,
            targetSize: size,
            positionAbove: positionAbove,
            onDismiss: _removeCard,
            onPlay: _play,
            onMoreInfo: _moreInfo,
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeCard() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _play() {
    _removeCard();
    final item = vodItem;
    // Access ProviderScope via context — widgets using this mixin are
    // always inside the Riverpod scope.
    final container = ProviderScope.containerOf(context);
    container
        .read(playbackSessionProvider.notifier)
        .startPlayback(
          streamUrl: item.streamUrl,
          isLive: false,
          channelName: item.name,
          channelLogoUrl: item.posterUrl,
          posterUrl: item.posterUrl,
          mediaType: item.type.mediaType,
        );
  }

  void _moreInfo() {
    _removeCard();
    final item = vodItem;
    final tag = '${item.id}_quick_info';
    if (item.type == VodType.movie) {
      context.push(AppRoutes.vodDetails, extra: {'item': item, 'heroTag': tag});
    } else {
      context.push(AppRoutes.seriesDetail, extra: item);
    }
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _removeCard();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  /// Returns a [KeyboardListener] + [GestureDetector] wrapper that
  /// triggers the Quick Info Card on TV dwell or mobile long-press.
  ///
  /// Wrap the poster widget with [buildQuickInfoWrapper].
  Widget buildQuickInfoWrapper({required Widget child}) {
    final isTV = MediaQuery.of(context).size.shortestSide >= 840;

    return Focus(
      focusNode: isTV ? _focusNode : null,
      onKeyEvent: (node, event) {
        // Dismiss on Back/Escape.
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack)) {
          _removeCard();
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        // Mobile: long-press triggers card immediately.
        onLongPress: isTV ? null : _showCard,
        child: child,
      ),
    );
  }
}

// ── Quick Info Overlay ────────────────────────────────

/// Positioned overlay card shown on D-pad focus dwell or mobile long-press.
///
/// - Semi-transparent glass background with [BackdropFilter].
/// - Shows: larger poster, title, year, rating, duration, genres, synopsis.
/// - "Play" and "More Info" action buttons.
/// - Dismisses on focus move, back press, or tap outside.
class _QuickInfoOverlay extends StatefulWidget {
  const _QuickInfoOverlay({
    required this.item,
    required this.targetOffset,
    required this.targetSize,
    required this.positionAbove,
    required this.onDismiss,
    required this.onPlay,
    required this.onMoreInfo,
  });

  final VodItem item;
  final Offset targetOffset;
  final Size targetSize;
  final bool positionAbove;
  final VoidCallback onDismiss;
  final VoidCallback onPlay;
  final VoidCallback onMoreInfo;

  @override
  State<_QuickInfoOverlay> createState() => _QuickInfoOverlayState();
}

class _QuickInfoOverlayState extends State<_QuickInfoOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: CrispyAnimation.normal);
    _fade = CurvedAnimation(parent: _ctrl, curve: CrispyAnimation.enterCurve);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;

    const double cardW = 320.0;
    const double cardH = 360.0;
    const double arrowH = 10.0;

    // Horizontal centering on target.
    double left =
        widget.targetOffset.dx + widget.targetSize.width / 2 - cardW / 2;
    final screenW = MediaQuery.of(context).size.width;
    left = left.clamp(CrispySpacing.md, screenW - cardW - CrispySpacing.md);

    double top;
    if (widget.positionAbove) {
      top = widget.targetOffset.dy - cardH - arrowH;
    } else {
      top = widget.targetOffset.dy + widget.targetSize.height + arrowH;
    }

    return GestureDetector(
      // Tap outside → dismiss.
      behavior: HitTestBehavior.translucent,
      onTap: widget.onDismiss,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: cardW,
              height: cardH,
              child: FadeTransition(
                opacity: _fade,
                child: GestureDetector(
                  // Prevent tap-outside from propagating through the card.
                  onTap: () {},
                  child: GlassSurface(
                    borderRadius: CrispyRadius.md,
                    blurSigma: 18,
                    tintColor: cs.surfaceContainerHigh.withValues(alpha: 0.9),
                    borderColor: cs.outline.withValues(alpha: 0.3),
                    child: _CardContent(
                      item: item,
                      cs: cs,
                      textTheme: textTheme,
                      onPlay: widget.onPlay,
                      onMoreInfo: widget.onMoreInfo,
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

/// Content layout inside the Quick Info Card.
class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.item,
    required this.cs,
    required this.textTheme,
    required this.onPlay,
    required this.onMoreInfo,
  });

  final VodItem item;
  final ColorScheme cs;
  final TextTheme textTheme;
  final VoidCallback onPlay;
  final VoidCallback onMoreInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Poster (top half).
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(CrispyRadius.md),
            ),
            child: SmartImage(
              itemId: item.id,
              title: item.name,
              imageUrl: item.backdropUrl ?? item.posterUrl,
              imageKind: 'backdrop',
              fit: BoxFit.cover,
              icon: Icons.movie,
              memCacheWidth: 640,
            ),
          ),
        ),

        // Metadata (bottom half).
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(CrispySpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title.
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: CrispySpacing.xxs),

                // Year · Rating · Duration.
                Wrap(
                  spacing: CrispySpacing.xs,
                  children: [
                    if (item.year != null)
                      _Pill(
                        label: '${item.year}',
                        cs: cs,
                        textTheme: textTheme,
                      ),
                    if (item.rating != null && item.rating!.isNotEmpty)
                      _Pill(label: item.rating!, cs: cs, textTheme: textTheme),
                    if (item.duration != null)
                      _Pill(
                        label: DurationFormatter.humanShort(
                          Duration(minutes: item.duration!),
                        ),
                        cs: cs,
                        textTheme: textTheme,
                      ),
                    if (item.category != null && item.category!.isNotEmpty)
                      _Pill(
                        label: item.category!,
                        cs: cs,
                        textTheme: textTheme,
                      ),
                  ],
                ),
                const SizedBox(height: CrispySpacing.xs),

                // Synopsis (short).
                if (item.description != null && item.description!.isNotEmpty)
                  Expanded(
                    child: Text(
                      item.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),

                const SizedBox(height: CrispySpacing.xs),

                // Action buttons.
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Play'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: CrispySpacing.xs,
                          ),
                          textStyle: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              CrispyRadius.tv,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: CrispySpacing.xs),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onMoreInfo,
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: const Text('More Info'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: CrispySpacing.xs,
                          ),
                          textStyle: textTheme.labelMedium,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              CrispyRadius.tv,
                            ),
                          ),
                          side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Small metadata pill label used inside the Quick Info Card.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.cs, required this.textTheme});

  final String label;
  final ColorScheme cs;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
