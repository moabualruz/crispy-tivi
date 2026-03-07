import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_typography.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/hover_builder.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../domain/entities/vod_item.dart';

/// Aspect ratio for 16:9 landscape cards.
const double _kLandscapeAspect = 16 / 9;

/// Match percentage threshold — displayed in green when >= this value.
const double _kHighMatchThreshold = 0.75;

/// A 16:9 landscape card for VOD items, used in
/// "More Like This" recommendation carousels.
///
/// Displays:
/// - Backdrop image (falls back to poster with letterboxing)
/// - Title (bottom overlay)
/// - Year and duration badges (bottom overlay)
/// - Match percentage indicator (top-right, when provided)
class VodLandscapeCard extends ConsumerWidget {
  const VodLandscapeCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.heroTag,
    this.matchPercent,
  });

  final VodItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? heroTag;

  /// Optional match percentage (0.0–1.0) shown as "XX% Match".
  /// When null, the indicator is omitted.
  final double? matchPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final safeHeroTag = heroTag ?? '${item.id}_landscape';
    final hasBackdrop =
        item.backdropUrl != null && item.backdropUrl!.trim().isNotEmpty;

    return Semantics(
      label: item.name,
      button: true,
      hint: 'Movie',
      child: HoverBuilder(
        builder:
            (context, isHovered) => FocusWrapper(
              scaleFactor: CrispyAnimation.hoverScale,
              onSelect: onTap ?? () {},
              onLongPress: onLongPress,
              borderRadius: CrispyRadius.tv,
              padding: EdgeInsets.zero,
              child: AspectRatio(
                aspectRatio: _kLandscapeAspect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Background image ──────────────────────
                      Hero(
                        tag: safeHeroTag,
                        child:
                            hasBackdrop
                                ? SmartImage(
                                  itemId: item.id,
                                  title: item.name,
                                  imageUrl: item.backdropUrl,
                                  imageKind: 'backdrop',
                                  icon: Icons.movie_outlined,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 480,
                                )
                                : _LetterboxedPoster(item: item),
                      ),

                      // ── Gradient scrim (bottom) ───────────────
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Bottom metadata overlay ───────────────
                      Positioned(
                        bottom: CrispySpacing.xs,
                        left: CrispySpacing.sm,
                        right: CrispySpacing.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Year + duration badges
                            Row(
                              children: [
                                if (item.year != null)
                                  _MetaBadge(
                                    label: '${item.year}',
                                    cs: cs,
                                    textTheme: textTheme,
                                  ),
                                if (item.year != null && item.duration != null)
                                  const SizedBox(width: CrispySpacing.xs),
                                if (item.duration != null)
                                  _MetaBadge(
                                    label: DurationFormatter.humanShort(
                                      Duration(minutes: item.duration!),
                                    ),
                                    cs: cs,
                                    textTheme: textTheme,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── Match percentage (top-right) ──────────
                      if (matchPercent != null)
                        Positioned(
                          top: CrispySpacing.xs,
                          right: CrispySpacing.xs,
                          child: _MatchBadge(
                            percent: matchPercent!,
                            textTheme: textTheme,
                          ),
                        ),

                      // ── Hover / focus play icon ───────────────
                      if (isHovered)
                        Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: CrispyColors.scrimMid,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

// ── Letterboxed poster fallback ────────────────────────────

/// Displays a 2:3 poster inside a 16:9 frame with letterboxing
/// when no backdrop URL is available.
class _LetterboxedPoster extends StatelessWidget {
  const _LetterboxedPoster({required this.item});

  final VodItem item;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: SmartImage(
            itemId: item.id,
            title: item.name,
            imageUrl: item.posterUrl,
            imageKind: 'poster',
            icon: Icons.movie_outlined,
            fit: BoxFit.cover,
            memCacheWidth: 200,
          ),
        ),
      ),
    );
  }
}

// ── Meta badge ────────────────────────────────────────────

/// Small semi-transparent badge for year/duration metadata.
class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.label,
    required this.cs,
    required this.textTheme,
  });

  final String label;
  final ColorScheme cs;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: textTheme.labelSmall?.copyWith(
        color: Colors.white70,
        fontSize: CrispyTypography.micro,
      ),
    );
  }
}

// ── Match percentage badge ────────────────────────────────

/// "XX% Match" badge shown in the top-right corner.
class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.percent, required this.textTheme});

  final double percent;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final isHigh = percent >= _kHighMatchThreshold;
    final color = isHigh ? Colors.green : Colors.white70;
    final label = '${(percent * 100).round()}% Match';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: CrispyColors.scrimMid,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: CrispyTypography.micro,
        ),
      ),
    );
  }
}
