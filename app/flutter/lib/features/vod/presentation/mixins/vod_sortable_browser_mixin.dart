import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';

/// Debounce duration applied to the VOD search field (S-019).
const Duration _kSearchDebounce = Duration(milliseconds: 500);

/// Shared sort/search state for VOD browser screens (movies & series).
///
/// Subclasses must implement [loadSortOption] and [saveSortOption] to
/// persist the selected [VodSortOption] via [SettingsNotifier].
mixin VodSortableBrowserMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  final searchController = TextEditingController();
  String? selectedCategory;
  String searchQuery = '';
  VodSortOption sortOption = VodSortOption.recentlyAdded;

  Timer? _searchDebounceTimer;

  /// Cached sorted+filtered item list (async, from Rust backend).
  List<VodItem> sortedItems = const [];

  // Snapshot of the inputs used for the last sort run.
  List<VodItem> _lastAll = const [];
  VodSortOption _lastSortOption = VodSortOption.recentlyAdded;
  String? _lastCategory;
  String _lastQuery = '';

  /// Load the persisted sort option from settings.
  /// Implementations call the appropriate `getXxxSortOption()` method.
  Future<String?> loadSortOption(SettingsNotifier notifier);

  /// Persist the chosen sort option to settings.
  /// Implementations call the appropriate `setXxxSortOption()` method.
  Future<void> saveSortOption(SettingsNotifier notifier, String value);

  /// Call in [initState] to restore the previously saved sort option.
  Future<void> initSortOption() async {
    final settings = ref.read(settingsNotifierProvider);
    final notifier =
        settings.value != null
            ? ref.read(settingsNotifierProvider.notifier)
            : null;
    if (notifier == null) return;
    final saved = await loadSortOption(notifier);
    if (saved != null && mounted) {
      final match = VodSortOption.values.where((o) => o.name == saved);
      if (match.isNotEmpty) {
        setState(() => sortOption = match.first);
      }
    }
  }

  /// Called on every keystroke from [VodSearchSortBar.onSearchChanged].
  ///
  /// Cancels any in-flight debounce timer and starts a fresh [_kSearchDebounce]
  /// countdown.  When the timer fires, [searchQuery] is updated and
  /// [checkAndRefreshSort] will pick up the change on the next build.
  void onSearchChangedDebounced(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      setState(() => searchQuery = query);
    });
  }

  /// Call when the user changes the sort option.
  Future<void> onSortOptionChanged(VodSortOption option) async {
    setState(() => sortOption = option);
    final settings = ref.read(settingsNotifierProvider);
    final notifier =
        settings.value != null
            ? ref.read(settingsNotifierProvider.notifier)
            : null;
    if (notifier == null) return;
    await saveSortOption(notifier, option.name);
  }

  /// Applies category/search filters, then delegates sorting to
  /// the Rust backend via [CacheService.filterAndSortVodItems].
  ///
  /// Stores the result in [sortedItems] and triggers a rebuild.
  Future<void> refreshSortedItems(List<VodItem> all) async {
    final cache = ref.read(cacheServiceProvider);
    final sorted = await cache.filterAndSortVodItems(
      all,
      category: selectedCategory,
      query: searchQuery.isNotEmpty ? searchQuery : null,
      sortByKey: sortOption.sortByKey,
    );
    if (!mounted) return;
    setState(() => sortedItems = sorted);
  }

  /// Compares current sort inputs against the last run and, if anything
  /// changed, schedules [refreshSortedItems] via a microtask so it does
  /// not block the current build.
  ///
  /// Call this inside `build()` after obtaining [allItems].  Subclasses
  /// may add their own guards (e.g. `!isLoading && error == null`) before
  /// calling this method.
  void checkAndRefreshSort(List<VodItem> allItems) {
    if (!identical(allItems, _lastAll) ||
        sortOption != _lastSortOption ||
        selectedCategory != _lastCategory ||
        searchQuery != _lastQuery) {
      _lastAll = allItems;
      _lastSortOption = sortOption;
      _lastCategory = selectedCategory;
      _lastQuery = searchQuery;
      Future.microtask(() => refreshSortedItems(allItems));
    }
  }

  /// Dispose the search controller and any pending debounce timer.
  /// Call before [super.dispose()].
  void disposeSortable() {
    _searchDebounceTimer?.cancel();
    searchController.dispose();
  }
}
