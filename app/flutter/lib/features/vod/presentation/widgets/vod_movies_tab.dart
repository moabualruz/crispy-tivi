import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/device_form_factor.dart';
import '../../../../core/widgets/genre_pill_row.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../domain/entities/vod_item.dart';
import '../mixins/vod_sortable_browser_mixin.dart';
import '../../../iptv/presentation/providers/playlist_sync_service.dart';
import '../providers/vod_providers.dart';
import 'vod_movies_grid.dart';
import 'vod_search_sort_bar.dart';

/// The movies tab content: search/sort bar,
/// continue watching, recommendations, swimlanes,
/// and category grid.
class VodMoviesTab extends ConsumerStatefulWidget {
  const VodMoviesTab({
    super.key,
    required this.movieCategories,
    required this.newReleases,
  });

  final List<String> movieCategories;
  final List<VodItem> newReleases;

  @override
  ConsumerState<VodMoviesTab> createState() => _VodMoviesTabState();
}

class _VodMoviesTabState extends ConsumerState<VodMoviesTab>
    with AutomaticKeepAliveClientMixin, VodSortableBrowserMixin<VodMoviesTab> {
  @override
  bool get wantKeepAlive => true;

  final _scrollController = ScrollController();
  VodGridDensity _density = VodGridDensity.standard;

  @override
  Future<String?> loadSortOption(SettingsNotifier notifier) =>
      notifier.getVodSortOption();

  @override
  Future<void> saveSortOption(SettingsNotifier notifier, String value) =>
      notifier.setVodSortOption(value);

  @override
  void initState() {
    super.initState();
    initializeSortedSource(
      ref.read(filteredMoviesProvider),
      (onItems) =>
          ref.listenManual(filteredMoviesProvider, (_, next) => onItems(next)),
    );
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
    super.build(context);
    final allFiltered = ref.watch(filteredMoviesProvider);

    final movieCategories = widget.movieCategories;
    final movies = visibleItemsOr(allFiltered);
    final isSearchOrCategory =
        selectedCategory != null || searchQuery.isNotEmpty;
    final itemsByCategory = <String, List<VodItem>>{};
    if (!isSearchOrCategory) {
      for (final item in movies) {
        final category = item.category;
        if (category == null || category.isEmpty) continue;
        (itemsByCategory[category] ??= <VodItem>[]).add(item);
      }
    }
    final hasCategorizedRows =
        movieCategories.isNotEmpty &&
        itemsByCategory.values.any((v) => v.isNotEmpty);

    return _wrapRefresh(
      CustomScrollView(
        key: const PageStorageKey('vod_movies'),
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: VodSearchSortBar(
              searchQuery: searchQuery,
              searchController: searchController,
              onSearchChanged: onSearchChangedDebounced,
              sortOption: sortOption,
              onSortChanged: onSortOptionChanged,
              gridDensity: _density,
              onDensityChanged: _onDensityChanged,
              onShuffle: () => _onShuffle(movies),
            ),
          ),
          // Source filter bar (hidden when ≤1 source).
          const SliverToBoxAdapter(child: SourceSelectorBar()),
          // Genre filter pills — always visible at top for discoverability.
          SliverToBoxAdapter(
            child: GenrePillRow(
              categories: movieCategories,
              selectedCategory: selectedCategory,
              onCategorySelected: onCategorySelected,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.sm)),
          if (isSearchOrCategory || !hasCategorizedRows) ...[
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
                final items = itemsByCategory[cat] ?? const <VodItem>[];
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
      ),
    );
  }
}
