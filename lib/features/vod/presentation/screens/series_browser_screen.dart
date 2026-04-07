import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/device_form_factor.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/genre_pill_row.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../../core/widgets/tv_color_button_legend.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../../iptv/presentation/providers/playlist_sync_service.dart';
import '../../../player/data/watch_history_service.dart';
import '../../domain/entities/vod_item.dart';
import '../mixins/vod_sortable_browser_mixin.dart';
import '../providers/vod_paginated_providers.dart';
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
  final _scrollController = ScrollController();

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

  // T03: Use paginated provider for series categories (SQL-level, no full load).
  List<String> get _seriesCategories {
    final async = ref.watch(vodCategoriesPaginatedProvider('series'));
    return (async.asData?.value ?? const <({String name, int count})>[])
        .where((c) => c.count > 0)
        .map((c) => c.name)
        .toList();
  }

  /// Wraps [child] in [RefreshIndicator] on mobile/tablet.
  Widget _wrapRefresh(Widget child) {
    if (!DeviceFormFactorService.current.isMobile) return child;
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(playlistSyncServiceProvider).syncAll();
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    disposeSortable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCountAsync = ref.watch(
      vodCountPaginatedProvider(const VodPageRequest(itemType: 'series')),
    );
    final allSeriesAsync = ref.watch(
      vodAllPaginatedProvider(const VodPageRequest(itemType: 'series')),
    );
    final totalCount = totalCountAsync.asData?.value;
    final allSeries = allSeriesAsync.asData?.value ?? const <VodItem>[];
    final shellError =
        totalCountAsync.whenOrNull(error: (err, _) => err.toString()) ??
        allSeriesAsync.whenOrNull(error: (err, _) => err.toString());

    // Re-sort whenever items, sort option, category, or query change.
    // Guards (isLoading, error, empty) live here so the mixin stays generic.
    if (!totalCountAsync.isLoading && shellError == null && allSeries.isNotEmpty) {
      checkAndRefreshSort(allSeries);
    }

    return VodBrowserShell(
      title: context.l10n.vodSeries,
      isLoading: totalCountAsync.isLoading || allSeriesAsync.isLoading,
      error: shellError,
      isEmpty: totalCount == 0,
      emptyIcon: Icons.tv_off,
      emptyTitle: context.l10n.vodNoItems,
      emptyDescription: 'Add a playlist source in Settings',
      onRetry: () {
        ref.invalidate(
          vodCountPaginatedProvider(const VodPageRequest(itemType: 'series')),
        );
        ref.invalidate(
          vodAllPaginatedProvider(const VodPageRequest(itemType: 'series')),
        );
        ref.invalidate(vodCategoriesPaginatedProvider('series'));
      },
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
              onPressed: () {
                // Scroll to top where the local VodSearchSortBar lives.
                _scrollController.animateTo(
                  0,
                  duration: CrispyAnimation.normal,
                  curve: CrispyAnimation.scrollCurve,
                );
              },
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
            compactBody: _buildBody(context, allSeries),
            largeBody: _buildBody(context, allSeries),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<VodItem> allSeries) {
    final seriesCategories = _seriesCategories;
    final favorites = allSeries.where((s) => s.isFavorite).toList();
    final series = sortedItems;
    final isSearchOrCategory =
        selectedCategory != null || searchQuery.isNotEmpty;
    final cw = ref.watch(continueWatchingSeriesProvider);
    // Resolve once per build; passed down to swimlane VodRow widgets.
    final newEpisodesIds = ref.watch(seriesWithNewEpisodesProvider);
    ContentBadge? newEpisodeBadge(VodItem item) =>
        newEpisodesIds.contains(item.id) ? ContentBadge.newEpisode : null;

    return _wrapRefresh(
      CustomScrollView(
        key: const PageStorageKey('series_browser'),
        controller: _scrollController,
        slivers: [
          // Search bar + sort controls
          SliverToBoxAdapter(
            child: VodSearchSortBar(
              searchQuery: searchQuery,
              searchController: searchController,
              hintText: 'Search series...',
              onSearchChanged: onSearchChangedDebounced,
              sortOption: sortOption,
              onSortChanged: onSortOptionChanged,
            ),
          ),

          // Source filter bar (hidden when ≤1 source).
          const SliverToBoxAdapter(child: SourceSelectorBar()),

          // Genre filter pills — always visible at top.
          SliverToBoxAdapter(
            child: GenrePillRow(
              categories: seriesCategories,
              selectedCategory: selectedCategory,
              onCategorySelected: (cat) {
                setState(() => selectedCategory = cat);
              },
            ),
          ),

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
                                title: context.l10n.vodContinueWatching,
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
          if (favorites.isNotEmpty && !isSearchOrCategory)
            SliverToBoxAdapter(
              child: VodRow(
                title: context.l10n.commonFavorites,
                icon: Icons.star,
                items: favorites,
                badgeBuilder: newEpisodeBadge,
              ),
            ),

          // Series grid or swimlanes
          if (isSearchOrCategory)
            SeriesMoviesGrid(series: series)
          else
            _buildCategorySwimlanes(seriesCategories, allSeries),

          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
        ],
      ),
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
