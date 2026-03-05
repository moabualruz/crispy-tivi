import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';
import 'media_grid.dart';
import 'vod_movies_grid.dart' show vodMaxExtent;
import 'vod_poster_card.dart';

/// Sliver grid of series poster cards with context menu support.
///
/// Thin wrapper around [MediaGrid] that provides the series-specific
/// item builder (new-episode badge, unwatched overlay, series navigation).
class SeriesMoviesGrid extends ConsumerWidget {
  const SeriesMoviesGrid({super.key, required this.series});

  final List<VodItem> series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double maxExtent = vodMaxExtent(context);

    // Resolve the set of series IDs with new episodes once per build.
    final newEpisodesIds = ref.watch(seriesWithNewEpisodesProvider);

    return MediaGrid<VodItem>(
      items: series,
      maxExtent: maxExtent,
      crossSpacingExtra: CrispySpacing.sm,
      mainSpacingExtra: CrispySpacing.md,
      itemBuilder:
          (ctx, item, autofocus) => _buildCard(
            context,
            ref,
            item,
            newEpisodesIds,
            autofocus: autofocus,
          ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    VodItem item,
    Set<String> newEpisodesIds, {
    bool autofocus = false,
  }) {
    final tag = '${item.id}_grid_series';
    final badge =
        newEpisodesIds.contains(item.id) ? ContentBadge.newEpisode : null;
    return VodPosterCard(
      item: item,
      heroTag: tag,
      badge: badge,
      autofocus: autofocus,
      overlayBuilder:
          (ctx, vodItem) =>
              _UnwatchedCountOverlay(seriesId: vodItem.id, ref: ref),
      onTap: () {
        context.push(AppRoutes.seriesDetail, extra: item);
      },
      onLongPress:
          () => showContextMenuPanel(
            context: context,
            sections: buildSeriesContextMenu(
              seriesName: item.name,
              isFavorite: item.isFavorite,
              colorScheme: Theme.of(context).colorScheme,
              onToggleFavorite:
                  () => ref.read(vodProvider.notifier).toggleFavorite(item.id),
              onViewDetails:
                  () => context.push(AppRoutes.seriesDetail, extra: item),
            ),
          ),
    );
  }
}

/// Small count badge showing the number of in-progress (started but
/// not completed) episodes for a series.
///
/// Positioned at the bottom-right of the poster. Renders nothing
/// when the count is 0 or not yet loaded.
class _UnwatchedCountOverlay extends StatelessWidget {
  const _UnwatchedCountOverlay({required this.seriesId, required this.ref});

  final String seriesId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final count =
        ref.watch(seriesUnwatchedCountProvider(seriesId)).asData?.value ?? 0;
    if (count <= 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      bottom: CrispySpacing.xs,
      right: CrispySpacing.xs,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
        ),
        child: Text(
          '$count',
          style: textTheme.labelSmall?.copyWith(
            color: cs.onSecondaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
