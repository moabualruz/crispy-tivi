import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/meta_chip.dart';
import '../../../../core/widgets/sliver_back_button.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/vignette_gradient.dart';
import '../../domain/entities/vod_item.dart';

const double _kHeroExpandedHeight = 400.0;

/// Netflix-style hero header for the series detail
/// screen.
///
/// Shows the backdrop/poster image with a bottom
/// vignette gradient, title, year, rating, and
/// category badges.
class SeriesHeroHeader extends StatelessWidget {
  const SeriesHeroHeader({
    super.key,
    required this.series,
    required this.isFavorite,
    required this.onBack,
    required this.onToggleFavorite,
  });

  final VodItem series;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SliverAppBar(
      expandedHeight: _kHeroExpandedHeight,
      pinned: true,
      backgroundColor: colorScheme.surface,
      leading: SliverBackButton(
        onPressed: onBack,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.54),
        iconColor: colorScheme.onSurface,
      ),
      actions: [
        IconButton(
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color:
                isFavorite
                    ? colorScheme.tertiary
                    : colorScheme.onSurfaceVariant,
          ),
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: onToggleFavorite,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _heroImage(colorScheme),
            VignetteGradient.surfaceAdaptive(),
            _titleOverlay(textTheme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _heroImage(ColorScheme cs) {
    if (series.backdropUrl != null && series.backdropUrl!.isNotEmpty) {
      return SmartImage(
        itemId: series.id,
        title: series.name,
        imageKind: 'backdrop',
        imageUrl: series.backdropUrl,
        fit: BoxFit.cover,
        // T09: limit decoded resolution to the hero expanded height to
        // avoid loading a full-resolution image into the image cache.
        memCacheHeight: _kHeroExpandedHeight.toInt(),
      );
    }
    if (series.posterUrl != null && series.posterUrl!.isNotEmpty) {
      return SmartImage(
        itemId: series.id,
        title: series.name,
        imageKind: 'poster',
        imageUrl: series.posterUrl,
        fit: BoxFit.cover,
        memCacheHeight: _kHeroExpandedHeight.toInt(),
      );
    }
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.tv, size: 64, color: cs.onSurfaceVariant),
    );
  }

  Widget _titleOverlay(TextTheme tt, ColorScheme colorScheme) {
    return Positioned(
      left: CrispySpacing.lg,
      right: CrispySpacing.lg,
      bottom: CrispySpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            series.name,
            style: tt.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: CrispyColors.vignetteEnd,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: CrispySpacing.sm),
          Row(
            children: [
              if (series.year != null) MetaChip(label: '${series.year}'),
              if (series.rating != null)
                MetaChip(label: series.rating!, color: colorScheme.tertiary),
              if (series.category != null) MetaChip(label: series.category!),
            ],
          ),
        ],
      ),
    );
  }
}
