import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/widgets/tv_color_button_legend.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../../player/data/watch_history_service.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';
import '../widgets/vod_catalog_browser.dart';
import '../widgets/vod_browser_shell.dart';
import '../widgets/continue_watching_section.dart';
import '../widgets/recently_added_section.dart';
import '../widgets/series_featured_banner.dart';
import '../widgets/series_movies_grid.dart';

/// Top-level Series browser screen (V2 navigation).
///
/// Extracted from the former `_SeriesTab` in
/// [VodBrowserScreen] to serve as a standalone shell
/// destination.
class SeriesBrowserScreen extends ConsumerStatefulWidget {
  const SeriesBrowserScreen({super.key});

  @override
  ConsumerState<SeriesBrowserScreen> createState() =>
      _SeriesBrowserScreenState();
}

class _SeriesBrowserScreenState extends ConsumerState<SeriesBrowserScreen> {
  @override
  Widget build(BuildContext context) {
    final vodState = ref.watch(vodProvider);
    final allSeries = ref.watch(filteredSeriesProvider);

    return VodBrowserShell(
      title: context.l10n.vodSeries,
      isLoading: vodState.isLoading,
      error: vodState.error,
      isEmpty:
          !vodState.isLoading && vodState.error == null && allSeries.isEmpty,
      emptyIcon: Icons.tv_off,
      emptyTitle: context.l10n.vodNoItems,
      emptyDescription: 'Add a playlist source in Settings',
      onRetry: () => ref.read(vodProvider.notifier).refreshFromBackend(),
      child: Scaffold(
        key: TestKeys.seriesBrowserScreen,
        appBar: AppBar(
          title: Text(context.l10n.vodSeries),
          actions: [
            IconButton(
              tooltip: context.l10n.homeMyList,
              icon: const Icon(Icons.playlist_add_check_rounded),
              onPressed: () => context.go(AppRoutes.favorites),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: context.l10n.searchTitle,
              onPressed: () => context.go(AppRoutes.customSearch),
            ),
          ],
        ),
        // T09: add Semantics label for screen reader accessibility.
        body: Semantics(
          label: 'Series browser',
          child: ScreenTemplate(
            focusRestorationKey: 'series-browser',
            colorButtonMap: {
              TvColorButton.red: ColorButtonAction(
                label: 'Filter',
                onPressed: () {},
              ),
              TvColorButton.green: ColorButtonAction(
                label: 'Search',
                onPressed: () => context.go(AppRoutes.customSearch),
              ),
              TvColorButton.yellow: ColorButtonAction(
                label: 'Sort',
                onPressed: () {},
              ),
              TvColorButton.blue: ColorButtonAction(
                label: 'My List',
                onPressed: () => context.go(AppRoutes.favorites),
              ),
            },
            compactBody: _buildBody(context),
            largeBody: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final initialItems = ref.watch(filteredSeriesProvider);
    return VodCatalogBrowser(
      initialItems: initialItems,
      currentItems: (ref) => ref.watch(filteredSeriesProvider),
      subscribe:
          (ref, onItems) => ref.listenManual(
            filteredSeriesProvider,
            (_, next) => onItems(next),
          ),
      hintText: 'Search series...',
      loadSortOption: (notifier) => notifier.getSeriesSortOption(),
      saveSortOption: (notifier, value) => notifier.setSeriesSortOption(value),
      maxCategories: 30,
      extraSliversBuilder: (context, ref, visibleItems, isSearchOrCategory) {
        final cw = ref.watch(continueWatchingSeriesProvider);
        final extra = <Widget>[];
        if (!isSearchOrCategory && visibleItems.isNotEmpty) {
          extra.add(
            SliverToBoxAdapter(
              child: SeriesFeaturedBanner(items: visibleItems),
            ),
          );
        }
        if (!isSearchOrCategory) {
          extra.addAll(
            cw.when(
              data:
                  (items) =>
                      items.isEmpty
                          ? <Widget>[]
                          : <Widget>[
                            SliverToBoxAdapter(
                              child: ContinueWatchingSection(
                                title: context.l10n.vodContinueWatching,
                                icon: Icons.play_circle_outline,
                                items: items,
                              ),
                            ),
                          ],
              loading: () => <Widget>[],
              error: (_, _) => <Widget>[],
            ),
          );
          extra.add(
            SliverToBoxAdapter(
              child: RecentlyAddedSection(
                showSeriesOnly: true,
                onItemTap: (item) {
                  context.push(AppRoutes.seriesDetail, extra: item);
                },
              ),
            ),
          );
        }
        return extra;
      },
      gridBuilder: (context, ref, items) => _SeriesGrid(items: items),
      rowBuilder: (context, ref, category, items) {
        return _SeriesCategoryRow(category: category, items: items);
      },
    );
  }
}

class _SeriesCategoryRow extends ConsumerWidget {
  const _SeriesCategoryRow({required this.category, required this.items});

  final String category;
  final List<VodItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newEpisodesIds = ref.watch(seriesWithNewEpisodesProvider);
    ContentBadge? newEpisodeBadge(VodItem item) =>
        newEpisodesIds.contains(item.id) ? ContentBadge.newEpisode : null;

    if (items.isEmpty) return const SizedBox.shrink();
    return VodRow(
      title: category,
      icon: Icons.tv,
      items: items,
      isTitleBadge: true,
      badgeBuilder: newEpisodeBadge,
    );
  }
}

class _SeriesGrid extends ConsumerWidget {
  const _SeriesGrid({required this.items});

  final List<VodItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SeriesMoviesGrid(series: items);
  }
}
