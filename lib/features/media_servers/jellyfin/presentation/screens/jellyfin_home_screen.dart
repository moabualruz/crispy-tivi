import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/widgets/horizontal_scroll_row.dart';
import '../../../shared/presentation/screens/media_server_home_screen.dart';
import '../../../shared/presentation/screens/paginated_library_screen.dart'
    show kPosterGridDelegate;
import '../../../shared/presentation/widgets/media_server_library_card.dart';
import '../../../shared/presentation/widgets/poster_card.dart';
import '../../../shared/presentation/widgets/watched_indicator.dart';
import '../../presentation/providers/jellyfin_providers.dart';

class JellyfinHomeScreen extends ConsumerWidget {
  const JellyfinHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(jellyfinSourceProvider);

    return MediaServerHomeScreen(
      serverName: source?.displayName ?? 'Jellyfin',
      isConnected: source != null,
      librariesProvider: jellyfinLibrariesProvider,
      libraryListBuilder: _buildLibraryList,
    );
  }

  Widget _buildLibraryList(List<MediaItem> libraries) {
    return _JellyfinHomeBody(libraries: libraries);
  }
}

// FE-JF-03: Personalized home body — replaces the earlier TODO stub.
/// Body of the Jellyfin home screen.
///
/// Personalized sections (JF-03):
/// 1. Continue Watching (JF-FE-04) — in-progress movies and episodes.
/// 2. Next Up (JF-FE-05) — next unwatched episode per in-progress series.
/// 3. Recently Added per library (JF-FE-06) — one row per library.
/// 4. Favorites (FE-JF-07).
/// 5. Full libraries grid.
class _JellyfinHomeBody extends ConsumerWidget {
  const _JellyfinHomeBody({required this.libraries});

  final List<MediaItem> libraries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-JF-04: Continue Watching data.
    final resumeAsync = ref.watch(jellyfinResumeItemsProvider);
    // FE-JF-05: Next Up data.
    final nextUpAsync = ref.watch(jellyfinNextUpProvider);
    // FE-JF-07: Favorites.
    final favoritesAsync = ref.watch(jellyfinFavoritesProvider);

    return CustomScrollView(
      slivers: [
        // ── FE-JF-04: Continue Watching ────────────────────────────────
        ...resumeAsync.when(
          data: (items) {
            if (items.isEmpty) return const <Widget>[];
            return [
              SliverToBoxAdapter(
                // FE-JF-04: horizontal row with progress-bar overlays.
                child: HorizontalScrollRow<MediaItem>(
                  headerIcon: Icons.play_circle_outline,
                  headerTitle: 'Continue Watching',
                  items: items,
                  itemWidth: 200,
                  sectionHeight: 150,
                  itemBuilder:
                      (ctx, item, _) => _JellyfinResumeCard(item: item),
                ),
              ),
            ];
          },
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
        ),

        // ── FE-JF-05: Next Up ──────────────────────────────────────────
        ...nextUpAsync.when(
          data: (items) {
            if (items.isEmpty) return const <Widget>[];
            return [
              SliverToBoxAdapter(
                // FE-JF-05: next episode row with episode + series label.
                child: HorizontalScrollRow<MediaItem>(
                  headerIcon: Icons.skip_next_outlined,
                  headerTitle: 'Next Up',
                  items: items,
                  itemWidth: 200,
                  sectionHeight: 150,
                  itemBuilder:
                      (ctx, item, _) => _JellyfinNextUpCard(item: item),
                ),
              ),
            ];
          },
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
        ),

        // ── FE-JF-06: Recently Added per library ───────────────────────
        ..._buildRecentlyAddedSections(ref),

        // ── Favorites (FE-JF-07) ───────────────────────────────────────
        ...favoritesAsync.when(
          data: (items) {
            if (items.isEmpty) return const <Widget>[];
            return [
              SliverToBoxAdapter(
                child: HorizontalScrollRow<MediaItem>(
                  headerIcon: Icons.favorite,
                  headerTitle: 'Favorites',
                  items: items,
                  itemWidth: 130,
                  sectionHeight: 200,
                  itemBuilder:
                      (ctx, item, _) => MediaServerLibraryCard(
                        library: item,
                        heroPrefix: 'jellyfin_fav',
                        routeBase: 'jellyfin',
                      ),
                ),
              ),
            ];
          },
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
        ),

        // ── Libraries Grid ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CrispySpacing.md,
              CrispySpacing.lg,
              CrispySpacing.md,
              CrispySpacing.sm,
            ),
            child: Text(
              'Libraries',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(CrispySpacing.md),
          sliver: SliverGrid(
            gridDelegate: kPosterGridDelegate,
            delegate: SliverChildBuilderDelegate((context, index) {
              final lib = libraries[index];
              return MediaServerLibraryCard(
                library: lib,
                heroPrefix: 'jellyfin',
                routeBase: 'jellyfin',
              );
            }, childCount: libraries.length),
          ),
        ),
      ],
    );
  }

  // FE-JF-06: One recently-added row per library, built eagerly.
  List<Widget> _buildRecentlyAddedSections(WidgetRef ref) {
    if (libraries.isEmpty) return const [];

    return libraries.map((library) {
      return _JellyfinRecentlyAddedSection(library: library);
    }).toList();
  }
}

// FE-JF-06: Per-library "Recently Added" sliver.
/// Watches [jellyfinRecentlyAddedByLibraryProvider] for [library] and
/// renders a [HorizontalScrollRow] when items are available.
class _JellyfinRecentlyAddedSection extends ConsumerWidget {
  const _JellyfinRecentlyAddedSection({required this.library});

  final MediaItem library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-JF-06: watch per-library recently-added provider.
    final recentAsync = ref.watch(
      jellyfinRecentlyAddedByLibraryProvider(library.id),
    );

    return recentAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return HorizontalScrollRow<MediaItem>(
          // FE-JF-06: label includes library name for clarity.
          headerIcon: Icons.new_releases_outlined,
          headerTitle: 'New in ${library.name}',
          items: items,
          itemWidth: 130,
          sectionHeight: 200,
          itemBuilder:
              (ctx, item, _) => MediaServerLibraryCard(
                library: item,
                heroPrefix: 'jellyfin_new_${library.id}',
                routeBase: 'jellyfin',
              ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// FE-JF-04: Resume card with landscape thumbnail and progress bar.
/// Landscape card for a "Continue Watching" item.
///
/// Tapping navigates to the details screen with resume enabled.
/// Shows a [WatchedIndicator] progress bar at the bottom.
class _JellyfinResumeCard extends StatelessWidget {
  const _JellyfinResumeCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return MediaServerPosterCard(
      imageUrl: item.logoUrl,
      title: item.name,
      semanticLabel: 'Resume watching',
      onTap: () => _navigateTo(context),
      // FE-JF-04: progress bar showing resume position.
      overlay: WatchedIndicator(
        isWatched: item.isWatched,
        isInProgress: item.isInProgress,
        watchProgress: item.watchProgress,
      ),
    );
  }

  void _navigateTo(BuildContext context) {
    // FE-JF-04: navigate to details for resume playback.
    if (item.type == MediaType.folder || item.type == MediaType.series) {
      context.push(AppRoutes.jellyfinLibrary(item.id, title: item.name));
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': MediaServerType.jellyfin,
          'heroTag': 'jellyfin_resume_${item.id}',
        },
      );
    }
  }
}

// FE-JF-05: Next Up card showing episode + series name.
/// Card for a "Next Up" episode.
///
/// Shows thumbnail, episode title, and parent series name.
class _JellyfinNextUpCard extends StatelessWidget {
  const _JellyfinNextUpCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // FE-JF-05: series name may be stored in metadata by data layer,
    // or fall back to parentId label.
    final seriesName = item.metadata['seriesName'] as String?;

    return Semantics(
      button: true,
      label: 'Continue watching',
      child: GestureDetector(
        onTap: () {
          // FE-JF-05: navigate to details screen.
          context.push(
            AppRoutes.mediaServerDetails,
            extra: {
              'item': item,
              'serverType': MediaServerType.jellyfin,
              'heroTag': 'jellyfin_nextup_${item.id}',
            },
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail.
              if (item.logoUrl != null)
                Image.network(
                  item.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) =>
                          ColoredBox(color: cs.surfaceContainerHighest),
                )
              else
                ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.tv, color: cs.onSurfaceVariant, size: 32),
                ),
              // Bottom gradient + episode + series labels.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        cs.surface.withValues(alpha: 0.88),
                        cs.surface.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    CrispySpacing.xs,
                    CrispySpacing.lg,
                    CrispySpacing.xs,
                    CrispySpacing.xxs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FE-JF-05: episode name.
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // FE-JF-05: series name below episode name.
                      if (seriesName != null)
                        Text(
                          seriesName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
