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
import 'package:crispy_tivi/core/widgets/responsive_layout.dart';
import '../../../shared/presentation/screens/media_server_home_screen.dart';
import '../../../shared/presentation/widgets/media_server_library_card.dart';
import '../../../shared/presentation/widgets/media_server_item_card.dart';
import '../../../shared/presentation/widgets/watched_indicator.dart';
import '../../presentation/providers/emby_providers.dart';
import '../widgets/emby_my_media_section.dart';

class EmbyHomeScreen extends ConsumerWidget {
  const EmbyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(embySourceProvider);

    return MediaServerHomeScreen(
      serverName: source?.displayName ?? 'Emby',
      isConnected: source != null,
      librariesProvider: embyLibrariesProvider,
      libraryListBuilder: _buildLibraryList,
    );
  }

  Widget _buildLibraryList(List<MediaItem> libraries) {
    return _EmbyLibraryBody(libraries: libraries);
  }
}

/// Full home body with personalized sections and library grid.
///
/// Sections rendered top to bottom:
///   1. My Media grid tiles (FE-EB-07)
///   2. Continue Watching row (FE-EB-04)
///   3. Next Up row (FE-EB-05)
///   4. Recently Added rows per library (FE-EB-06)
///   5. Collections / Box Sets row (FE-EB-10)
///   6. Libraries poster scroll
class _EmbyLibraryBody extends ConsumerWidget {
  const _EmbyLibraryBody({required this.libraries});

  final List<MediaItem> libraries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-EB-04
    final resumeAsync = ref.watch(embyResumeItemsProvider);
    // FE-EB-05
    final nextUpAsync = ref.watch(embyNextUpProvider);
    // FE-EB-10
    final collectionsAsync = ref.watch(embyCollectionsProvider);

    final posterHeight = switch (context.layoutClass) {
      LayoutClass.compact => 200.0,
      LayoutClass.medium => 240.0,
      _ => 280.0,
    };
    final posterWidth = posterHeight * (2 / 3);

    return CustomScrollView(
      slivers: [
        // ── My Media grid (FE-EB-07) ──────────────────────────────
        SliverToBoxAdapter(child: EmbyMyMediaSection(libraries: libraries)),

        // ── Continue Watching (FE-EB-04) ──────────────────────────
        ...resumeAsync.when(
          data: (items) {
            if (items.isEmpty) return const <Widget>[];
            // FE-EB-04
            return [
              SliverToBoxAdapter(
                child: HorizontalScrollRow<MediaItem>(
                  headerIcon: Icons.play_circle_outline,
                  headerTitle: 'Continue Watching',
                  items: items,
                  itemWidth: posterWidth,
                  sectionHeight: posterHeight,
                  itemBuilder: (ctx, item, _) => _EmbyResumeCard(item: item),
                ),
              ),
            ];
          },
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
        ),

        // ── Next Up (FE-EB-05) ─────────────────────────────────────
        ...nextUpAsync.when(
          data: (items) {
            if (items.isEmpty) return const <Widget>[];
            // FE-EB-05
            return [
              SliverToBoxAdapter(
                child: HorizontalScrollRow<MediaItem>(
                  headerIcon: Icons.skip_next_outlined,
                  headerTitle: 'Next Up',
                  items: items,
                  itemWidth: posterWidth,
                  sectionHeight: posterHeight,
                  itemBuilder: (ctx, item, _) => _EmbyNextUpCard(item: item),
                ),
              ),
            ];
          },
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
        ),

        // ── Recently Added per Library (FE-EB-06) ─────────────────
        for (final lib in libraries)
          _EmbyRecentlyAddedSection(
            library: lib,
            posterWidth: posterWidth,
            posterHeight: posterHeight,
          ),

        // ── Collections / Box Sets (FE-EB-10) ─────────────────────
        ...collectionsAsync.when(
          data: (items) {
            if (items.isEmpty) return const <Widget>[];
            // FE-EB-10
            return [
              SliverToBoxAdapter(
                child: HorizontalScrollRow<MediaItem>(
                  headerIcon: Icons.collections_outlined,
                  headerTitle: 'Collections',
                  items: items,
                  itemWidth: posterWidth,
                  sectionHeight: posterHeight,
                  itemBuilder:
                      (ctx, item, _) => _EmbyCollectionCard(item: item),
                ),
              ),
            ];
          },
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
        ),

        // ── Libraries poster scroll ────────────────────────────────
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
        SliverToBoxAdapter(
          child: SizedBox(
            height: switch (context.layoutClass) {
              LayoutClass.compact => 220.0,
              LayoutClass.medium => 280.0,
              _ => 320.0,
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xl),
              scrollDirection: Axis.horizontal,
              itemCount: libraries.length,
              separatorBuilder:
                  (_, _) => const SizedBox(width: CrispySpacing.md),
              itemBuilder: (context, index) {
                final lib = libraries[index];
                final cardWidth = (MediaQuery.sizeOf(context).width * 0.25)
                    .clamp(120.0, 220.0);
                return SizedBox(
                  width: cardWidth,
                  child: MediaServerLibraryCard(
                    library: lib,
                    heroPrefix: 'emby',
                    routeBase: 'emby',
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.lg)),
      ],
    );
  }
}

// ── FE-EB-06: Recently Added section (per library) ────────────────────────

/// FE-EB-06: A horizontally scrollable row of recently added items for
/// a single [library], rendered as a [SliverToBoxAdapter].
class _EmbyRecentlyAddedSection extends ConsumerWidget {
  const _EmbyRecentlyAddedSection({
    required this.library,
    required this.posterWidth,
    required this.posterHeight,
  });

  final MediaItem library;
  final double posterWidth;
  final double posterHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-EB-06
    final recentAsync = ref.watch(embyRecentlyAddedProvider(library.id));

    return recentAsync.when(
      data: (items) {
        if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
        return SliverToBoxAdapter(
          child: HorizontalScrollRow<MediaItem>(
            headerIcon: Icons.new_releases_outlined,
            headerTitle: 'Recently Added — ${library.name}',
            items: items,
            itemWidth: posterWidth,
            sectionHeight: posterHeight,
            itemBuilder:
                (ctx, item, _) => MediaServerItemCard(
                  item: item,
                  serverType: MediaServerType.emby,
                  getStreamUrl:
                      (itemId) =>
                          ref.read(embyStreamUrlProvider(itemId).future),
                  heroPrefix: 'emby_recent_${library.id}',
                ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox()),
    );
  }
}

// ── FE-EB-04: Resume card ─────────────────────────────────────────────────

/// FE-EB-04: Poster card for an in-progress item with a playback
/// progress bar overlay. Tapping navigates to the details screen.
class _EmbyResumeCard extends ConsumerWidget {
  const _EmbyResumeCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-EB-04
    final cs = Theme.of(context).colorScheme;
    final progress = item.watchProgress;

    return GestureDetector(
      onTap: () => _navigate(context, ref),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image
            if (item.logoUrl != null)
              Image.network(
                item.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => ColoredBox(
                      color: cs.surfaceContainerHigh,
                      child: Icon(
                        Icons.movie_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
              )
            else
              ColoredBox(
                color: cs.surfaceContainerHigh,
                child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant),
              ),
            // Progress bar overlay
            if (progress != null && progress > 0)
              WatchedIndicator(
                isWatched: false,
                isInProgress: true,
                watchProgress: progress,
              ),
            // Title scrim at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  CrispySpacing.xs,
                  CrispySpacing.lg,
                  CrispySpacing.xs,
                  CrispySpacing.xs,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      cs.surface.withValues(alpha: 0.85),
                      cs.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, WidgetRef ref) {
    // FE-EB-04
    if (item.type == MediaType.folder || item.type == MediaType.series) {
      context.push(
        '/emby/library/${item.id}?title=${Uri.encodeComponent(item.name)}',
      );
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': MediaServerType.emby,
          'getStreamUrl':
              (String itemId) => ref.read(embyStreamUrlProvider(itemId).future),
          'heroTag': 'emby_resume_${item.id}',
        },
      );
    }
  }
}

// ── FE-EB-05: Next Up card ────────────────────────────────────────────────

/// FE-EB-05: Poster card for the "Next Up" row, showing the episode
/// name and series name as a subtitle below the image.
class _EmbyNextUpCard extends ConsumerWidget {
  const _EmbyNextUpCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-EB-05
    final cs = Theme.of(context).colorScheme;
    final seriesName = item.metadata['SeriesName'] as String?;

    return GestureDetector(
      onTap: () => _navigate(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.logoUrl != null)
                    Image.network(
                      item.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, _, _) => ColoredBox(
                            color: cs.surfaceContainerHigh,
                            child: Icon(
                              Icons.tv_outlined,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                    )
                  else
                    ColoredBox(
                      color: cs.surfaceContainerHigh,
                      child: Icon(
                        Icons.tv_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
          // Episode name
          Text(
            item.name,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Series name (FE-EB-05 requirement)
          if (seriesName != null)
            Text(
              seriesName,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, WidgetRef ref) {
    // FE-EB-05
    context.push(
      AppRoutes.mediaServerDetails,
      extra: {
        'item': item,
        'serverType': MediaServerType.emby,
        'getStreamUrl':
            (String itemId) => ref.read(embyStreamUrlProvider(itemId).future),
        'heroTag': 'emby_nextup_${item.id}',
      },
    );
  }
}

// ── FE-EB-10: Collection card ─────────────────────────────────────────────

/// FE-EB-10: Poster card for a BoxSet collection with a child-count
/// badge in the bottom-left corner.
class _EmbyCollectionCard extends StatelessWidget {
  const _EmbyCollectionCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    // FE-EB-10
    final cs = Theme.of(context).colorScheme;
    final childCount = item.metadata['ChildCount'];
    final countLabel =
        childCount != null
            ? '$childCount item${childCount == 1 ? '' : 's'}'
            : null;

    return GestureDetector(
      onTap: () {
        // FE-EB-10: drill into collection contents using paginated library
        context.push(
          '/emby/library/${item.id}?title=${Uri.encodeComponent(item.name)}',
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image
            if (item.logoUrl != null)
              Image.network(
                item.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => ColoredBox(
                      color: cs.surfaceContainerHigh,
                      child: Icon(
                        Icons.collections_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
              )
            else
              ColoredBox(
                color: cs.surfaceContainerHigh,
                child: Icon(
                  Icons.collections_outlined,
                  color: cs.onSurfaceVariant,
                ),
              ),
            // Child count badge (bottom-left)
            if (countLabel != null)
              Positioned(
                left: CrispySpacing.xs,
                bottom: CrispySpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.xs,
                    vertical: CrispySpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                  child: Text(
                    countLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            // Title scrim
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  CrispySpacing.xs,
                  CrispySpacing.lg,
                  CrispySpacing.xs,
                  CrispySpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      cs.surface.withValues(alpha: 0.85),
                      cs.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
