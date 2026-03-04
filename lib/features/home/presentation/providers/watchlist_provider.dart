import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../profiles/data/profile_service.dart';
import '../../../vod/domain/entities/vod_item.dart';

// FE-H-01: My List / Watchlist provider

/// Watchlist state — an ordered list of saved [VodItem]s.
class WatchlistState {
  const WatchlistState({this.items = const []});

  final List<VodItem> items;

  /// Returns a new state with [item] added (if not already present).
  WatchlistState add(VodItem item) {
    if (items.any((i) => i.id == item.id)) return this;
    return WatchlistState(items: [...items, item]);
  }

  /// Returns a new state with the item matching [itemId] removed.
  WatchlistState remove(String itemId) {
    return WatchlistState(items: items.where((i) => i.id != itemId).toList());
  }

  /// Whether [itemId] is in the watchlist.
  bool contains(String itemId) => items.any((i) => i.id == itemId);
}

/// Manages the "My List" watchlist.
///
/// Persists to a Rust/DB table so the list survives app restarts.
class WatchlistNotifier extends AsyncNotifier<WatchlistState> {
  @override
  Future<WatchlistState> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final pid = _activeProfileId;
    if (pid == null) return const WatchlistState();

    final items = await cache.getWatchlistItems(pid);
    return WatchlistState(items: items);
  }

  String? get _activeProfileId {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    return ref
        .read(profileServiceProvider.notifier)
        .state
        .value
        ?.activeProfileId;
  }

  /// Adds [item] to the watchlist.
  Future<void> add(VodItem item) async {
    final cache = ref.read(cacheServiceProvider);
    final pid = _activeProfileId;
    if (pid == null) return;

    await cache.addWatchlistItem(pid, item.id);

    final current = state.value ?? const WatchlistState();
    state = AsyncData(current.add(item));
  }

  /// Removes the item with [itemId] from the watchlist.
  Future<void> remove(String itemId) async {
    final cache = ref.read(cacheServiceProvider);
    final pid = _activeProfileId;
    if (pid == null) return;

    await cache.removeWatchlistItem(pid, itemId);

    final current = state.value ?? const WatchlistState();
    state = AsyncData(current.remove(itemId));
  }

  /// Toggles [item] in the watchlist — adds if absent, removes if present.
  Future<void> toggle(VodItem item) async {
    if (state.value?.contains(item.id) ?? false) {
      await remove(item.id);
    } else {
      await add(item);
    }
  }
}

/// Global watchlist provider.
final watchlistProvider =
    AsyncNotifierProvider<WatchlistNotifier, WatchlistState>(
      WatchlistNotifier.new,
    );

/// Convenience selector: `true` when [itemId] is in the watchlist.
///
/// Subscribe with `.select()` so the widget rebuilds only when
/// this specific item's membership changes:
/// ```dart
/// ref.watch(watchlistItemContainsProvider(item.id));
/// ```
// Wait, family provider for selection. Wait, `select` on `watchlistProvider`
// can be used, but since it's AsyncValue now, we return false if loading.
final watchlistItemCountProvider = Provider<int>((ref) {
  return ref.watch(watchlistProvider).value?.items.length ?? 0;
});
