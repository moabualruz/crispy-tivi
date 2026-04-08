import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_favorites_provider.dart';
import 'vod_landscape_card.dart';

export '../../../../core/widgets/meta_chip.dart' show MetaChip;

/// Small bordered rectangle showing quality label
/// (e.g. "HD", "4K"). Cinematic style with sharp
/// corners.
class QualityBadge extends StatelessWidget {
  const QualityBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CrispyRadius.none),
        border: Border.all(color: cs.onSurface),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Landscape card width for the "More Like This" carousel.
///
/// At 16:9, the card height matches the standard section height minus
/// the header row (~40 px), so the carousel remains one card tall.
double vodLandscapeCardWidth(double screenWidth) =>
    screenWidth >= Breakpoints.expanded
        ? 280.0
        : screenWidth >= Breakpoints.medium
        ? 240.0
        : 210.0;

/// Section height for the 16:9 landscape carousel (header + card).
double vodLandscapeSectionHeight(double screenWidth) {
  // card height = width * (9/16), plus header (~40 px) and bottom gap
  final cardH = vodLandscapeCardWidth(screenWidth) * 9 / 16;
  return cardH + 56; // 56 = header row height
}

/// "More Like This" horizontal carousel of 16:9 landscape cards
/// for movie recommendations.
///
/// Each card shows: backdrop (or letterboxed poster), title,
/// year, duration, and an optional match % indicator.
///
/// Delegates scroll scaffolding to [HorizontalScrollRow].
class MovieRecommendationsSection extends ConsumerWidget {
  const MovieRecommendationsSection({super.key, required this.recommendations});

  final List<VodItem> recommendations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final cardW = vodLandscapeCardWidth(w);
    final sectionH = vodLandscapeSectionHeight(w);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HorizontalScrollRow<VodItem>(
          items: recommendations,
          itemWidth: cardW,
          sectionHeight: sectionH,
          headerTitle: 'More Like This',
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
          itemSpacing: CrispySpacing.sm,
          itemBuilder: (context, movie, index) {
            final tag = '${movie.id}_mlt_$index';
            return VodLandscapeCard(
              item: movie,
              heroTag: tag,
              onTap: () {
                context.push(
                  AppRoutes.vodDetails,
                  extra: {'item': movie, 'heroTag': tag},
                );
              },
              onLongPress: () {
                final cs = Theme.of(context).colorScheme;
                showContextMenuPanel(
                  context: context,
                  sections: buildMovieContextMenu(
                    context: context,
                    movieName: movie.name,
                    isFavorite: movie.isFavorite,
                    colorScheme: cs,
                    onToggleFavorite:
                        () => ref
                            .read(vodFavoritesProvider.notifier)
                            .toggleFavorite(movie.id),
                    onPlay:
                        () => ref
                            .read(playbackSessionProvider.notifier)
                            .startPlayback(
                              streamUrl: movie.streamUrl,
                              isLive: false,
                              channelName: movie.name,
                              channelLogoUrl: movie.posterUrl,
                            ),
                    onViewDetails:
                        () => context.push(
                          AppRoutes.vodDetails,
                          extra: {'item': movie, 'heroTag': tag},
                        ),
                    onCopyUrl: () => copyStreamUrl(context, movie.streamUrl),
                    onOpenExternal:
                        hasExternalPlayer(ref)
                            ? () => openInExternalPlayer(
                              context: context,
                              ref: ref,
                              streamUrl: movie.streamUrl,
                              title: movie.name,
                            )
                            : null,
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: CrispySpacing.xxl),
      ],
    );
  }
}
