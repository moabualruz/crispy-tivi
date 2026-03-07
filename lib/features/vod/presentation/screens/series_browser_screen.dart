import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/genre_pill_row.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../../player/data/watch_history_service.dart';
import '../../domain/entities/vod_item.dart';
import '../mixins/vod_sortable_browser_mixin.dart';
import '../providers/vod_providers.dart';
import '../widgets/vod_browser_shell.dart';
import '../widgets/continue_watching_section.dart';
import '../widgets/recently_added_section.dart';
import '../widgets/series_featured_banner.dart';
import '../widgets/series_movies_grid.dart';
import '../widgets/vod_search_sort_bar.dart';

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

class _SeriesBrowserScreenState extends ConsumerState<SeriesBrowserScreen>
    with VodSortableBrowserMixin<SeriesBrowserScreen> {
  @override
  Future<String?> loadSortOption(SettingsNotifier notifier) =>
      notifier.getSeriesSortOption();

  @override
  Future<void> saveSortOption(SettingsNotifier notifier, String value) =>
      notifier.setSeriesSortOption(value);

  @override
  void initState() {
    super.initState();
    initSortOption();
  }

  List<VodItem> get _allFilteredSeries => ref.watch(filteredSeriesProvider);

  List<VodItem> get _favorites =>
      _allFilteredSeries.where((s) => s.isFavorite).toList();

  // T03: Use pre-computed VodState.seriesCategories instead of re-computing
  // from filteredSeriesProvider on every build.
  List<String> get _seriesCategories =>
      ref.watch(vodProvider.select((s) => s.seriesCategories));

  @override
  void dispose() {
    disposeSortable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // T04: surgical selectors — only rebuild when isLoading or error changes.
    final isLoading = ref.watch(vodProvider.select((s) => s.isLoading));
    final error = ref.watch(vodProvider.select((s) => s.error));
    final allSeries = _allFilteredSeries;

    // Re-sort whenever items, sort option, category, or query change.
    // Guards (isLoading, error, empty) live here so the mixin stays generic.
    if (!isLoading && error == null && allSeries.isNotEmpty) {
      checkAndRefreshSort(allSeries);
    }

    return VodBrowserShell(
      title: 'Series',
      isLoading: isLoading,
      error: error,
      isEmpty: allSeries.isEmpty,
      emptyIcon: Icons.tv_off,
      emptyTitle: 'No series available',
      emptyDescription: 'Add a playlist source in Settings',
      child: Scaffold(
        key: TestKeys.seriesBrowserScreen,
        appBar: AppBar(
          title: const Text('Series'),
          actions: [
            IconButton(
              tooltip: 'My List',
              icon: const Icon(Icons.playlist_add_check_rounded),
              onPressed: () => context.go(AppRoutes.favorites),
            ),
            const AppBarSearchButton(),
          ],
        ),
        // T09: add Semantics label for screen reader accessibility.
        body: Semantics(
          label: 'Series browser',
          child: FocusTraversalGroup(child: _buildBody(context, allSeries)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<VodItem> allSeries) {
    final seriesCategories = _seriesCategories;
    final series = sortedItems;
    final isSearchOrCategory =
        selectedCategory != null || searchQuery.isNotEmpty;
    final cw = ref.watch(continueWatchingSeriesProvider);
    // Resolve once per build; passed down to swimlane VodRow widgets.
    final newEpisodesIds = ref.watch(seriesWithNewEpisodesProvider);
    ContentBadge? newEpisodeBadge(VodItem item) =>
        newEpisodesIds.contains(item.id) ? ContentBadge.newEpisode : null;

    return CustomScrollView(
      slivers: [
        // Search bar + sort controls
        SliverToBoxAdapter(
          child: VodSearchSortBar(
            searchQuery: searchQuery,
            searchController: searchController,
            hintText: 'Search series...',
            onSearchChanged: (q) {
              setState(() => searchQuery = q);
            },
            sortOption: sortOption,
            onSortChanged: onSortOptionChanged,
          ),
        ),

        // Source filter bar (hidden when ≤1 source).
        const SliverToBoxAdapter(child: SourceSelectorBar()),

        // T10: Featured series hero banner (hidden during search/filter).
        if (!isSearchOrCategory && allSeries.isNotEmpty)
          SliverToBoxAdapter(child: SeriesFeaturedBanner(items: allSeries)),

        // Continue watching
        if (!isSearchOrCategory)
          ...cw.when(
            data:
                (items) =>
                    items.isEmpty
                        ? <Widget>[]
                        : <Widget>[
                          SliverToBoxAdapter(
                            child: ContinueWatchingSection(
                              title: 'Continue Watching',
                              icon: Icons.play_circle_outline,
                              items: items,
                            ),
                          ),
                        ],
            loading: () => <Widget>[],
            error: (_, _) => <Widget>[],
          ),

        // Recently Added Series
        if (!isSearchOrCategory)
          SliverToBoxAdapter(
            child: RecentlyAddedSection(
              showSeriesOnly: true,
              onItemTap: (item) {
                context.push(AppRoutes.seriesDetail, extra: item);
              },
            ),
          ),

        // Favorites
        if (_favorites.isNotEmpty && !isSearchOrCategory)
          SliverToBoxAdapter(
            child: VodRow(
              title: 'Favorites',
              icon: Icons.star,
              items: _favorites,
              badgeBuilder: newEpisodeBadge,
            ),
          ),

        // Genre pill row
        SliverToBoxAdapter(
          child: GenrePillRow(
            categories: seriesCategories,
            selectedCategory: selectedCategory,
            onCategorySelected: (cat) {
              setState(() => selectedCategory = cat);
            },
          ),
        ),

        // Series grid or swimlanes
        if (isSearchOrCategory)
          SeriesMoviesGrid(series: series)
        else
          _buildCategorySwimlanes(seriesCategories, allSeries),

        const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
      ],
    );
  }

  Widget _buildCategorySwimlanes(
    List<String> seriesCategories,
    List<VodItem> allSeries,
  ) {
    // T08: pre-filter categories that have no items so the sliver builder
    // never receives an empty group.
    final nonEmptyCategories =
        seriesCategories
            .where((cat) => allSeries.any((s) => s.category == cat))
            .toList();

    // Resolve new-episodes set once for all swimlanes.
    final newEpisodesIds = ref.watch(seriesWithNewEpisodesProvider);
    ContentBadge? newEpisodeBadge(VodItem item) =>
        newEpisodesIds.contains(item.id) ? ContentBadge.newEpisode : null;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = nonEmptyCategories[index];
        final categorySeries =
            allSeries.where((s) => s.category == category).toList();

        return VodRow(
          title: category,
          icon: Icons.tv,
          items: categorySeries,
          isTitleBadge: true,
          badgeBuilder: newEpisodeBadge,
        );
      }, childCount: nonEmptyCategories.length),
    );
  }
}
