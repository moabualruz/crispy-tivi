import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/device_form_factor.dart';
import '../../../../core/widgets/genre_pill_row.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../iptv/presentation/providers/playlist_sync_service.dart';
import '../../domain/entities/vod_item.dart';
import '../mixins/vod_sortable_browser_mixin.dart';
import 'vod_search_sort_bar.dart';

typedef VodCatalogExtraSliversBuilder =
    List<Widget> Function(
      BuildContext context,
      WidgetRef ref,
      List<VodItem> visibleItems,
      bool isSearchOrCategory,
    );

typedef VodCatalogGridBuilder =
    Widget Function(BuildContext context, WidgetRef ref, List<VodItem> items);

typedef VodCatalogRowBuilder =
    Widget Function(
      BuildContext context,
      WidgetRef ref,
      String category,
      List<VodItem> items,
    );

/// Shared search/sort/filter/render body for Movies and Series browsers.
///
/// This centralizes:
/// - persisted sort behavior
/// - debounced search
/// - category/group derivation
/// - flat-grid fallback when taxonomy is absent
/// - shared sliver layout for compact and TV surfaces
class VodCatalogBrowser extends ConsumerStatefulWidget {
  const VodCatalogBrowser({
    super.key,
    required this.initialItems,
    required this.currentItems,
    required this.subscribe,
    required this.hintText,
    required this.loadSortOption,
    required this.saveSortOption,
    required this.gridBuilder,
    required this.rowBuilder,
    this.maxCategories = 30,
    this.extraSliversBuilder,
  });

  final List<VodItem> initialItems;
  final List<VodItem> Function(WidgetRef ref) currentItems;
  final ProviderSubscription<List<VodItem>> Function(
    WidgetRef ref,
    void Function(List<VodItem>) onItems,
  )
  subscribe;
  final String hintText;
  final Future<String?> Function(SettingsNotifier notifier) loadSortOption;
  final Future<void> Function(SettingsNotifier notifier, String value)
  saveSortOption;
  final VodCatalogGridBuilder gridBuilder;
  final VodCatalogRowBuilder rowBuilder;
  final int maxCategories;
  final VodCatalogExtraSliversBuilder? extraSliversBuilder;

  @override
  ConsumerState<VodCatalogBrowser> createState() => _VodCatalogBrowserState();
}

class _VodCatalogBrowserState extends ConsumerState<VodCatalogBrowser>
    with
        AutomaticKeepAliveClientMixin,
        VodSortableBrowserMixin<VodCatalogBrowser> {
  @override
  bool get wantKeepAlive => true;

  final _scrollController = ScrollController();

  @override
  Future<String?> loadSortOption(SettingsNotifier notifier) =>
      widget.loadSortOption(notifier);

  @override
  Future<void> saveSortOption(SettingsNotifier notifier, String value) =>
      widget.saveSortOption(notifier, value);

  @override
  void initState() {
    super.initState();
    initializeSortedSource(
      widget.initialItems,
      (onItems) => widget.subscribe(ref, onItems),
    );
    initSortOption();
  }

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
    final allItems = widget.currentItems(ref);
    final visibleItems = visibleItemsOr(allItems);

    final categoryCounts = <String, int>{};
    for (final item in allItems) {
      final category = item.category;
      if (category == null || category.isEmpty) continue;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    final categoryNames =
        categoryCounts.entries.toList()..sort((a, b) {
          final countCmp = b.value.compareTo(a.value);
          if (countCmp != 0) return countCmp;
          return a.key.compareTo(b.key);
        });

    final limitedCategoryNames =
        categoryNames
            .take(widget.maxCategories)
            .map((entry) => entry.key)
            .toList();

    final itemsByCategory = <String, List<VodItem>>{};
    for (final item in visibleItems) {
      final category = item.category;
      if (category == null || category.isEmpty) continue;
      (itemsByCategory[category] ??= <VodItem>[]).add(item);
    }

    final isSearchOrCategory =
        selectedCategory != null || searchQuery.trim().isNotEmpty;
    final hasCategorizedRows =
        limitedCategoryNames.isNotEmpty &&
        limitedCategoryNames.any(
          (category) =>
              (itemsByCategory[category] ?? const <VodItem>[]).isNotEmpty,
        );

    return _wrapRefresh(
      CustomScrollView(
        key: PageStorageKey('${widget.hintText}_catalog'),
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: VodSearchSortBar(
              searchQuery: searchQuery,
              searchController: searchController,
              hintText: widget.hintText,
              onSearchChanged: onSearchChangedDebounced,
              sortOption: sortOption,
              onSortChanged: onSortOptionChanged,
            ),
          ),
          const SliverToBoxAdapter(child: SourceSelectorBar()),
          SliverToBoxAdapter(
            child: GenrePillRow(
              categories: limitedCategoryNames,
              selectedCategory: selectedCategory,
              onCategorySelected: onCategorySelected,
            ),
          ),
          if (widget.extraSliversBuilder != null)
            ...widget.extraSliversBuilder!(
              context,
              ref,
              visibleItems,
              isSearchOrCategory,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.sm)),
          if (isSearchOrCategory || !hasCategorizedRows)
            widget.gridBuilder(context, ref, visibleItems)
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final category = limitedCategoryNames[index];
                return widget.rowBuilder(
                  context,
                  ref,
                  category,
                  itemsByCategory[category] ?? const <VodItem>[],
                );
              }, childCount: limitedCategoryNames.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
        ],
      ),
    );
  }
}
