import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';
import 'media_grid.dart';
import 'vod_poster_card.dart';
import 'vod_search_sort_bar.dart';

/// Responsive max card extent for VOD poster grids.
///
/// Used when [VodGridDensity] is not explicitly supplied.
double vodMaxExtent(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoints.large) return 240;
  if (w >= Breakpoints.expanded) return 220;
  if (w >= Breakpoints.medium) return 200;
  return 170;
}

/// Sliver grid of VOD movie poster cards with context menu support.
///
/// Thin wrapper around [VodDensityMediaGrid] that provides the
/// movie-specific item builder (navigation, context menu, playback).
class VodMoviesGrid extends ConsumerWidget {
  const VodMoviesGrid({
    super.key,
    required this.movies,
    this.density = VodGridDensity.standard,
  });

  final List<VodItem> movies;

  /// Grid density — controls card size and items per row.
  final VodGridDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VodDensityMediaGrid<VodItem>(
      items: movies,
      density: density,
      crossSpacingExtra: CrispySpacing.xs,
      mainSpacingExtra: CrispySpacing.sm,
      semanticIndexCallback: (_, index) => index,
      itemBuilder:
          (ctx, item, autofocus) =>
              _buildCard(context, ref, item, autofocus: autofocus),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    VodItem item, {
    bool autofocus = false,
  }) {
    final tag = '${item.id}_grid_movies';
    return VodPosterCard(
      item: item,
      heroTag: tag,
      autofocus: autofocus,
      onTap: () {
        context.push(
          AppRoutes.vodDetails,
          extra: {'item': item, 'heroTag': tag},
        );
      },
      onLongPress:
          () => showContextMenuPanel(
            context: context,
            sections: buildMovieContextMenu(
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
              onViewDetails: () {
                context.push(
                  AppRoutes.vodDetails,
                  extra: {'item': item, 'heroTag': tag},
                );
              },
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
            ),
          ),
    );
  }
}
