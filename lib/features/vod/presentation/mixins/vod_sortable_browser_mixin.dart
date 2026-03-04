import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../providers/vod_providers.dart';

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

  /// Dispose the search controller. Call before [super.dispose()].
  void disposeSortable() {
    searchController.dispose();
  }
}
