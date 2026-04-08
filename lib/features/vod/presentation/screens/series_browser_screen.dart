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
import '../widgets/vod_search_sort_bar.dart';
import '../widgets/vod_poster_card.dart';

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
  // Cap to top 30 by count — 1500+ genre pills is unusable.
  List<String> get _seriesCategories {
    final async = ref.watch(vodCategoriesPaginatedProvider('series'));
    final all = (async.asData?.value ?? const <({String name, int count})>[])
        .where((c) => c.count > 0)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return all.take(30).map((c) => c.name).toList();
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
    final firstPageSeriesAsync = ref.watch(
      vodPagePaginatedProvider(const VodPageRequest(itemType: 'series')),
    );
    final totalCount = totalCountAsync.asData?.value;
    final firstPageSeries = firstPageSeriesAsync.asData?.value ?? const <VodItem>[];
    final shellError =
        totalCountAsync.whenOrNull(error: (err, _) => err.toString()) ??
        firstPageSeriesAsync.whenOrNull(error: (err, _) => err.toString());

    // Re-sort whenever items, sort option, category, or query change.
    // Guards (isLoading, error, empty) live here so the mixin stays generic.
    if (!totalCountAsync.isLoading &&
        shellError == null &&
        firstPageSeries.isNotEmpty &&
        (selectedCategory != null || searchQuery.isNotEmpty)) {
      checkAndRefreshSort(firstPageSeries);
    }

    return VodBrowserShell(
      title: context.l10n.vodSeries,
      isLoading: totalCountAsync.isLoading || firstPageSeriesAsync.isLoading,
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
          vodPagePaginatedProvider(const VodPageRequest(itemType: 'series')),
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
            compactBody: _buildBody(context, firstPageSeries),
            largeBody: _buildBody(context, firstPageSeries),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<VodItem> firstPageSeries) {
    final seriesCategories = _seriesCategories;
    final isSearchOrCategory =
        selectedCategory != null || searchQuery.isNotEmpty;
    final cw = ref.watch(continueWatchingSeriesProvider);

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
          if (!isSearchOrCategory && firstPageSeries.isNotEmpty)
            SliverToBoxAdapter(
              child: SeriesFeaturedBanner(items: firstPageSeries),
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
            _PaginatedSeriesGrid(
              category: selectedCategory,
              query: searchQuery.isEmpty ? null : searchQuery,
              sort: sortOption.sortByKey,
            )
          else
            _buildCategorySwimlanes(seriesCategories),

          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
        ],
      ),
    );
  }

  /// Cap swimlane rows to avoid 1500+ concurrent widget builds.
  static const _kMaxSwimlaneCategories = 20;

  Widget _buildCategorySwimlanes(List<String> seriesCategories) {
    final capped = seriesCategories.take(_kMaxSwimlaneCategories).toList();
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = capped[index];
        return _PaginatedSeriesCategoryRow(
          category: category,
          sort: sortOption.sortByKey,
        );
      }, childCount: capped.length),
    );
  }
}

class _PaginatedSeriesCategoryRow extends ConsumerWidget {
  const _PaginatedSeriesCategoryRow({
    required this.category,
    required this.sort,
  });

  final String category;
  final String sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(
      vodPagePaginatedProvider(
        VodPageRequest(
          itemType: 'series',
          category: category,
          sort: sort,
          page: 0,
        ),
      ),
    );
    final newEpisodesIds = ref.watch(seriesWithNewEpisodesProvider);
    ContentBadge? newEpisodeBadge(VodItem item) =>
        newEpisodesIds.contains(item.id) ? ContentBadge.newEpisode : null;

    return pageAsync.when(
      data:
          (items) =>
              items.isEmpty
                  ? const SizedBox.shrink()
                  : VodRow(
                    title: category,
                    icon: Icons.tv,
                    items: items,
                    isTitleBadge: true,
                    badgeBuilder: newEpisodeBadge,
                  ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PaginatedSeriesGrid extends ConsumerWidget {
  const _PaginatedSeriesGrid({
    required this.sort,
    this.category,
    this.query,
  });

  final String? category;
  final String? query;
  final String sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      vodCountPaginatedProvider(
        VodPageRequest(
          itemType: 'series',
          category: category,
          query: query,
          sort: sort,
        ),
      ),
    );
    final itemCount = countAsync.asData?.value ?? kVodPageSize;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 2 / 3,
          mainAxisSpacing: CrispySpacing.md,
          crossAxisSpacing: CrispySpacing.sm,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final page = index ~/ kVodPageSize;
          final indexInPage = index % kVodPageSize;
          final request = VodPageRequest(
            itemType: 'series',
            category: category,
            query: query,
            sort: sort,
            page: page,
          );
          final pageAsync = ref.watch(vodPagePaginatedProvider(request));
          final newEpisodesIds = ref.watch(seriesWithNewEpisodesProvider);

          return pageAsync.when(
            data: (items) {
              if (indexInPage >= items.length) return const SizedBox.shrink();
              final item = items[indexInPage];
              final badge =
                  newEpisodesIds.contains(item.id)
                      ? ContentBadge.newEpisode
                      : null;
              return VodPosterCard(
                item: item,
                badge: badge,
                onTap: () => context.push(AppRoutes.seriesDetail, extra: item),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          );
        }, childCount: itemCount),
      ),
    );
  }
}
