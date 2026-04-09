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
    initializeSortedSource(
      ref.read(filteredSeriesProvider),
      (onItems) =>
          ref.listenManual(filteredSeriesProvider, (_, next) => onItems(next)),
    );
    initSortOption();
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
    final vodState = ref.watch(vodProvider);
    final allSeries = ref.watch(filteredSeriesProvider);
    final visibleSeries = visibleItemsOr(allSeries);
    final categoryCounts = <String, int>{};
    for (final item in allSeries) {
      final category = item.category;
      if (category == null || category.isEmpty) continue;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }
    final seriesCategories =
        categoryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

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
            compactBody: _buildBody(
              context,
              visibleSeries,
              seriesCategories.take(30).map((entry) => entry.key).toList(),
            ),
            largeBody: _buildBody(
              context,
              visibleSeries,
              seriesCategories.take(30).map((entry) => entry.key).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<VodItem> visibleSeries,
    List<String> seriesCategories,
  ) {
    final isSearchOrCategory =
        selectedCategory != null || searchQuery.isNotEmpty;
    final cw = ref.watch(continueWatchingSeriesProvider);
    final itemsByCategory = <String, List<VodItem>>{};
    for (final item in visibleSeries) {
      final category = item.category;
      if (category == null || category.isEmpty) continue;
      (itemsByCategory[category] ??= <VodItem>[]).add(item);
    }

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
              onCategorySelected: onCategorySelected,
            ),
          ),

          // T10: Featured series hero banner (hidden during search/filter).
          if (!isSearchOrCategory && visibleSeries.isNotEmpty)
            SliverToBoxAdapter(
              child: SeriesFeaturedBanner(items: visibleSeries),
            ),

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

          // Series grid or swimlanes
          if (isSearchOrCategory)
            _SeriesGrid(items: visibleSeries)
          else
            _buildCategorySwimlanes(seriesCategories, itemsByCategory),

          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
        ],
      ),
    );
  }

  /// Cap swimlane rows to avoid 1500+ concurrent widget builds.
  static const _kMaxSwimlaneCategories = 20;

  Widget _buildCategorySwimlanes(
    List<String> seriesCategories,
    Map<String, List<VodItem>> itemsByCategory,
  ) {
    final capped = seriesCategories.take(_kMaxSwimlaneCategories).toList();
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = capped[index];
        return _SeriesCategoryRow(
          category: category,
          items: itemsByCategory[category] ?? const <VodItem>[],
        );
      }, childCount: capped.length),
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
