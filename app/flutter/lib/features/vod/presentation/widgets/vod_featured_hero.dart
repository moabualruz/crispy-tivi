import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/vignette_gradient.dart';
import '../../domain/entities/vod_item.dart';

// FE-VODS-04: Hero banner auto-cycle with trailer.

/// Auto-cycling cinematic hero for the VOD browser.
///
/// Behaviour:
/// - Cycles through [items] (up to [_kMaxItems]) every [_kCycleDuration].
/// - Fade transition between items ([CrispyAnimation.slow]).
/// - Progress dots below the banner indicate the active item.
/// - Focus/hover pauses the auto-cycle.
/// - Items with a non-null [VodItem.backdropUrl] auto-play a muted
///   trailer after [CrispyAnimation.trailerDelayFeatured] (2 s); cycle resumes after 15 s
///   or when the trailer ends naturally.
/// - Tapping the banner navigates to the VOD detail screen.
class VodFeaturedHero extends ConsumerStatefulWidget {
  const VodFeaturedHero({super.key, required this.items});

  final List<VodItem> items;

  @override
  ConsumerState<VodFeaturedHero> createState() => _VodFeaturedHeroState();
}

const int _kMaxItems = 5;
const Duration _kCycleDuration = CrispyAnimation.heroAdvanceInterval;
const Duration _kTrailerDelay = CrispyAnimation.trailerDelayFeatured;
const Duration _kTrailerMaxDuration = Duration(seconds: 15);

class _VodFeaturedHeroState extends ConsumerState<VodFeaturedHero> {
  int _current = 0;
  bool _paused = false;
  bool _showTrailer = false;
  Timer? _cycleTimer;
  Timer? _trailerTimer;
  Timer? _trailerMaxTimer;

  List<VodItem> get _items => widget.items.take(_kMaxItems).toList();

  @override
  void initState() {
    super.initState();
    _startCycle();
  }

  void _startCycle() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(_kCycleDuration, (_) {
      if (!_paused) _advance();
    });
    _scheduleTrailer();
  }

  void _scheduleTrailer() {
    _trailerTimer?.cancel();
    _trailerMaxTimer?.cancel();
    _showTrailer = false;
    final item = _items.isNotEmpty ? _items[_current] : null;
    if (item?.backdropUrl != null && item!.backdropUrl!.isNotEmpty) {
      _trailerTimer = Timer(_kTrailerDelay, () {
        if (!mounted) return;
        setState(() => _showTrailer = true);
        // Resume cycle after trailer max duration.
        _trailerMaxTimer = Timer(_kTrailerMaxDuration, () {
          if (!mounted) return;
          setState(() => _showTrailer = false);
          if (!_paused) _advance();
        });
      });
    }
  }

  void _advance() {
    if (_items.isEmpty) return;
    setState(() {
      _showTrailer = false;
      _current = (_current + 1) % _items.length;
    });
    _scheduleTrailer();
  }

  void _goTo(int index) {
    if (index == _current) return;
    setState(() {
      _showTrailer = false;
      _current = index;
    });
    _scheduleTrailer();
  }

  void _onFocusEnter() {
    setState(() => _paused = true);
  }

  void _onFocusExit() {
    setState(() => _paused = false);
  }

  void _tap() {
    final items = _items;
    if (items.isEmpty) return;
    final item = items[_current];
    final tag = '${item.id}_featured_hero';
    if (item.type == VodType.movie) {
      context.push(AppRoutes.vodDetails, extra: {'item': item, 'heroTag': tag});
    } else {
      context.push(AppRoutes.seriesDetail, extra: item);
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _trailerTimer?.cancel();
    _trailerMaxTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final heroH =
        w >= Breakpoints.expanded
            ? 480.0
            : (w >= Breakpoints.medium ? 380.0 : 280.0);
    final item = items[_current];

    return MouseRegion(
      onEnter: (_) => _onFocusEnter(),
      onExit: (_) => _onFocusExit(),
      child: Semantics(
        button: true,
        label: 'View details',
        child: GestureDetector(
          onTap: _tap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Hero image area ──
              SizedBox(
                height: heroH,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Backdrop poster with AnimatedSwitcher for fade transition.
                    AnimatedSwitcher(
                      duration: CrispyAnimation.slow,
                      switchInCurve: CrispyAnimation.enterCurve,
                      switchOutCurve: CrispyAnimation.exitCurve,
                      child: SmartImage(
                        key: TestKeys.heroItem(item.id),
                        itemId: item.id,
                        title: item.name,
                        imageUrl: item.backdropUrl ?? item.posterUrl,
                        imageKind: 'backdrop',
                        fit: BoxFit.cover,
                        icon: Icons.movie,
                        memCacheWidth: 1200,
                      ),
                    ),

                    // Trailer indicator overlay — subtle border pulse when active.
                    // Full video playback requires a `trailerUrl` domain field.
                    if (_showTrailer)
                      AnimatedOpacity(
                        opacity: _showTrailer ? 1.0 : 0.0,
                        duration: CrispyAnimation.normal,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.6),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(
                              CrispyRadius.tv,
                            ),
                          ),
                        ),
                      ),

                    // Bottom gradient scrim for text legibility.
                    Positioned.fill(child: VignetteGradient.surfaceScrim()),

                    // Title + metadata overlay at the bottom.
                    Positioned(
                      left: CrispySpacing.md,
                      right: CrispySpacing.md,
                      bottom: CrispySpacing.md,
                      child: AnimatedSwitcher(
                        duration: CrispyAnimation.normal,
                        child: _HeroMeta(
                          key: TestKeys.metaItem(item.id),
                          item: item,
                          textTheme: textTheme,
                          cs: cs,
                          showTrailer: _showTrailer,
                        ),
                      ),
                    ),

                    // Trailer badge (top-right) when trailer is playing.
                    if (_showTrailer)
                      Positioned(
                        top: CrispySpacing.sm,
                        right: CrispySpacing.sm,
                        child: _TrailerBadge(cs: cs, textTheme: textTheme),
                      ),
                  ],
                ),
              ),

              // ── Progress dots ──
              if (items.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CrispySpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(items.length, (i) {
                      return GestureDetector(
                        onTap: () => _goTo(i),
                        child: AnimatedContainer(
                          duration: CrispyAnimation.fast,
                          margin: const EdgeInsets.symmetric(
                            horizontal: CrispySpacing.xxs,
                          ),
                          width: i == _current ? 20 : 8,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                i == _current
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                              CrispyRadius.tv,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Metadata overlay: title, year, rating, genre chips.
class _HeroMeta extends StatelessWidget {
  const _HeroMeta({
    super.key,
    required this.item,
    required this.textTheme,
    required this.cs,
    required this.showTrailer,
  });

  final VodItem item;
  final TextTheme textTheme;
  final ColorScheme cs;
  final bool showTrailer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.name,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: CrispySpacing.xs),
        Wrap(
          spacing: CrispySpacing.xs,
          children: [
            if (item.year != null)
              _MetaPill(label: '${item.year}', cs: cs, textTheme: textTheme),
            if (item.rating != null && item.rating!.isNotEmpty)
              _MetaPill(label: item.rating!, cs: cs, textTheme: textTheme),
            if (item.category != null && item.category!.isNotEmpty)
              _MetaPill(label: item.category!, cs: cs, textTheme: textTheme),
          ],
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.cs,
    required this.textTheme,
  });

  final String label;
  final ColorScheme cs;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Small "TRAILER" badge shown in top-right when trailer is active.
class _TrailerBadge extends StatelessWidget {
  const _TrailerBadge({required this.cs, required this.textTheme});

  final ColorScheme cs;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        'TRAILER',
        style: textTheme.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
