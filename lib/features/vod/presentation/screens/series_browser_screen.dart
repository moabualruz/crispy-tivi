import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/device_form_factor.dart';
import '../../../../core/widgets/alpha_jump_bar.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../../core/widgets/content_badge.dart';
import '../../../../core/widgets/genre_pill_row.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../../iptv/application/playlist_sync_service.dart';
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
    initSortOption();
  }

  List<VodItem> get _allFilteredSeries => ref.watch(filteredSeriesProvider);

  List<VodItem> get _favorites =>
      _allFilteredSeries.where((s) => s.isFavorite).toList();

  // T03: Use pre-computed VodState.seriesCategories instead of re-computing
  // from filteredSeriesProvider on every build.
  List<String> get _seriesCategories =>
      ref.watch(vodProvider.select((s) => s.seriesCategories));

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
      title: context.l10n.vodSeries,
      isLoading: isLoading,
      error: error,
      isEmpty: allSeries.isEmpty,
      emptyIcon: Icons.tv_off,
      emptyTitle: context.l10n.vodNoItems,
      emptyDescription: 'Add a playlist source in Settings',
      onRetry: () => ref.invalidate(vodProvider),
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

    final names = allSeries.map((s) => s.name).toList();
    final indexOffsets = AlphaJumpBar.computeIndexOffsets(names);

    return Stack(
      children: [
        _wrapRefresh(
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
                SliverToBoxAdapter(
                  child: SeriesFeaturedBanner(items: allSeries),
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

              // Favorites
              if (_favorites.isNotEmpty && !isSearchOrCategory)
                SliverToBoxAdapter(
                  child: VodRow(
                    title: context.l10n.commonFavorites,
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

              const SliverToBoxAdapter(
                child: SizedBox(height: CrispySpacing.xl),
              ),
            ],
          ),
        ),
        // Alpha jump bar — right edge.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _SeriesAlphaJumpAdapter(
            scrollController: _scrollController,
            indexOffsets: indexOffsets,
            totalItemCount: allSeries.length,
          ),
        ),
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

/// Adapter that converts index-based offsets to pixel offsets
/// once the scroll controller's max extent is known.
class _SeriesAlphaJumpAdapter extends StatefulWidget {
  final ScrollController scrollController;
  final Map<String, double> indexOffsets;
  final int totalItemCount;

  const _SeriesAlphaJumpAdapter({
    required this.scrollController,
    required this.indexOffsets,
    required this.totalItemCount,
  });

  @override
  State<_SeriesAlphaJumpAdapter> createState() =>
      _SeriesAlphaJumpAdapterState();
}

class _SeriesAlphaJumpAdapterState extends State<_SeriesAlphaJumpAdapter> {
  Map<String, double> _pixelOffsets = const {};
  bool _extentReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_SeriesAlphaJumpAdapter old) {
    super.didUpdateWidget(old);
    if (old.indexOffsets != widget.indexOffsets ||
        old.totalItemCount != widget.totalItemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!_extentReady && widget.scrollController.hasClients) {
      _update();
    }
  }

  void _update() {
    if (!widget.scrollController.hasClients) return;
    final maxExtent = widget.scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    _extentReady = true;
    final scaled = AlphaJumpBar.scaleOffsets(
      widget.indexOffsets,
      maxExtent,
      widget.totalItemCount,
    );
    if (mounted) setState(() => _pixelOffsets = scaled);
  }

  @override
  Widget build(BuildContext context) {
    return AlphaJumpBar(
      controller: widget.scrollController,
      sectionOffsets: _pixelOffsets,
      totalItemCount: widget.totalItemCount,
    );
  }
}
