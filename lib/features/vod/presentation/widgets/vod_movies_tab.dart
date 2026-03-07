import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/genre_pill_row.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../recommendations/presentation/providers/recommendation_providers.dart';
import '../../../recommendations/presentation/widgets/recommendation_section_widget.dart';
import '../../domain/entities/vod_item.dart';
import '../mixins/vod_sortable_browser_mixin.dart';
import '../providers/vod_providers.dart';
import 'continue_watching_section.dart';
import 'recently_added_section.dart';
import 'vod_featured_hero.dart';
import 'vod_movies_grid.dart';
import 'vod_search_sort_bar.dart';

/// The movies tab content: search/sort bar,
/// continue watching, recommendations, swimlanes,
/// and category grid.
class VodMoviesTab extends ConsumerStatefulWidget {
  const VodMoviesTab({super.key, required this.state});
  final VodState state;

  @override
  ConsumerState<VodMoviesTab> createState() => _VodMoviesTabState();
}

class _VodMoviesTabState extends ConsumerState<VodMoviesTab>
    with AutomaticKeepAliveClientMixin, VodSortableBrowserMixin<VodMoviesTab> {
  @override
  bool get wantKeepAlive => true;

  VodGridDensity _density = VodGridDensity.standard;

  /// Cached sorted+filtered movie list (async, from Rust backend).
  List<VodItem> _sortedMovies = const [];

  /// Inputs that were used for the last sort — compared each build
  /// to decide whether to re-trigger a sort.
  List<VodItem> _lastAll = const [];
  VodSortOption _lastSortOption = VodSortOption.recentlyAdded;
  String? _lastCategory;
  String _lastQuery = '';

  @override
  Future<String?> loadSortOption(SettingsNotifier notifier) =>
      notifier.getVodSortOption();

  @override
  Future<void> saveSortOption(SettingsNotifier notifier, String value) =>
      notifier.setVodSortOption(value);

  @override
  void initState() {
    super.initState();
    initSortOption();
    _loadDensity();
  }

  /// Loads the persisted grid density and updates local state.
  Future<void> _loadDensity() async {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final raw = await notifier.getVodGridDensity();
    if (!mounted) return;
    final density = VodGridDensity.values.firstWhere(
      (d) => d.name == raw,
      orElse: () => VodGridDensity.standard,
    );
    if (density != _density) setState(() => _density = density);
  }

  /// Cycles to the next density mode and persists the choice.
  void _onDensityChanged(VodGridDensity next) {
    setState(() => _density = next);
    ref.read(settingsNotifierProvider.notifier).setVodGridDensity(next.name);
  }

  void _onShuffle(List<VodItem> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No items to shuffle')));
      return;
    }
    final item = items[math.Random().nextInt(items.length)];
    final tag = '${item.id}_shuffle';
    context.push(AppRoutes.vodDetails, extra: {'item': item, 'heroTag': tag});
  }

  /// Applies category/search filters, then delegates sorting to
  /// the Rust backend via [CacheService.filterAndSortVodItems].
  ///
  /// Stores the result in [_sortedMovies] and triggers a rebuild.
  Future<void> _refreshSortedMovies(List<VodItem> all) async {
    final cache = ref.read(cacheServiceProvider);
    final sorted = await cache.filterAndSortVodItems(
      all,
      category: selectedCategory,
      query: searchQuery.isNotEmpty ? searchQuery : null,
      sortByKey: sortOption.sortByKey,
    );
    if (!mounted) return;
    setState(() => _sortedMovies = sorted);
  }

  List<Widget> _buildRecommendations() {
    final sections = ref.watch(vodRecommendationsProvider);
    if (sections.isEmpty) return [];

    final visible = sections.where((s) => s.items.isNotEmpty).take(2).toList();
    if (visible.isEmpty) return [];

    return [
      SliverToBoxAdapter(child: RecommendationSectionWidget(sections: visible)),
    ];
  }

  @override
  void dispose() {
    disposeSortable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allFiltered = ref.watch(filteredMoviesProvider);

    // Re-sort whenever items, sort option, category, or query change.
    if (!identical(allFiltered, _lastAll) ||
        sortOption != _lastSortOption ||
        selectedCategory != _lastCategory ||
        searchQuery != _lastQuery) {
      _lastAll = allFiltered;
      _lastSortOption = sortOption;
      _lastCategory = selectedCategory;
      _lastQuery = searchQuery;
      // Schedule async sort without blocking the build.
      Future.microtask(() => _refreshSortedMovies(allFiltered));
    }

    final cw = ref.watch(continueWatchingMoviesProvider);
    // Categories and new releases come from VodState (pre-computed).
    final movieCategories = widget.state.movieCategories;
    final newReleases = widget.state.newReleases;
    // Hero banner and favorites are pre-computed by providers (O(1) read).
    final featured = ref.watch(featuredMoviesProvider);
    final favorites = ref.watch(favoriteMoviesProvider);
    final movies = _sortedMovies;
    final isSearchOrCategory =
        selectedCategory != null || searchQuery.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: VodSearchSortBar(
            searchQuery: searchQuery,
            searchController: searchController,
            onSearchChanged: (q) {
              setState(() => searchQuery = q);
            },
            sortOption: sortOption,
            onSortChanged: onSortOptionChanged,
            gridDensity: _density,
            onDensityChanged: _onDensityChanged,
            onShuffle: () => _onShuffle(movies),
          ),
        ),
        // Source filter bar (hidden when ≤1 source).
        const SliverToBoxAdapter(child: SourceSelectorBar()),
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
        if (!isSearchOrCategory) ..._buildRecommendations(),
        if (!isSearchOrCategory)
          SliverToBoxAdapter(
            child: RecentlyAddedSection(
              showMoviesOnly: true,
              onItemTap: (item) {
                final tag = '${item.id}_recently_added';
                context.push(
                  AppRoutes.vodDetails,
                  extra: {'item': item, 'heroTag': tag},
                );
              },
            ),
          ),
        if (newReleases.isNotEmpty && !isSearchOrCategory)
          SliverToBoxAdapter(
            child: VodRow(
              title: 'New Releases',
              icon: Icons.new_releases,
              items: newReleases,
              isTitleBadge: true,
            ),
          ),
        if (favorites.isNotEmpty && !isSearchOrCategory)
          SliverToBoxAdapter(
            child: VodRow(
              title: 'Favorites',
              icon: Icons.star,
              items: favorites,
            ),
          ),
        // FE-VODS-04: Auto-cycling featured hero with trailer support.
        if (featured.isNotEmpty && !isSearchOrCategory)
          SliverToBoxAdapter(child: VodFeaturedHero(items: featured)),
        SliverToBoxAdapter(
          child: GenrePillRow(
            categories: movieCategories,
            selectedCategory: selectedCategory,
            onCategorySelected: (cat) {
              setState(() => selectedCategory = cat);
            },
          ),
        ),
        if (isSearchOrCategory) ...[
          SliverToBoxAdapter(
            child: Semantics(
              label: 'Movies grid',
              container: true,
              child: const SizedBox.shrink(),
            ),
          ),
          VodMoviesGrid(movies: movies, density: _density),
        ] else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final cat = movieCategories[index];
              final items =
                  allFiltered.where((m) => m.category == cat).toList();
              if (items.isEmpty) {
                return const SizedBox.shrink();
              }
              return VodRow(
                title: cat,
                icon: Icons.local_movies,
                items: items,
                isTitleBadge: true,
              );
            }, childCount: movieCategories.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
      ],
    );
  }
}
