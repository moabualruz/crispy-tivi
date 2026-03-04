import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../profiles/data/profile_service.dart';

/// Manages profile-scoped VOD favorites (movies + series).
///
/// State is a [Set<String>] of favorite VOD item IDs.
class VodFavoritesController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    // Watch profile state so we rebuild when the profile loads or switches.
    final profileState = ref.watch(profileServiceProvider);
    final pid = profileState.value?.activeProfileId;
    if (pid == null) return {};
    final ids = await cache.getVodFavorites(pid);
    return ids.toSet();
  }

  String? get _activeProfileId {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    return ref
        .read(profileServiceProvider.notifier)
        .state
        .value
        ?.activeProfileId;
  }

  /// Toggle the favorite status of a VOD item.
  Future<void> toggleFavorite(String vodItemId) async {
    final cache = ref.read(cacheServiceProvider);
    final pid = _activeProfileId;
    if (pid == null) return;

    final current = state.value ?? {};
    if (current.contains(vodItemId)) {
      await cache.removeVodFavorite(pid, vodItemId);
      state = AsyncData({...current}..remove(vodItemId));
    } else {
      await cache.addVodFavorite(pid, vodItemId);
      state = AsyncData({...current, vodItemId});
    }
  }

  /// Synchronous check whether an item is favorited.
  bool isFavorite(String vodItemId) =>
      state.value?.contains(vodItemId) ?? false;
}

/// Provider for profile-scoped VOD favorites.
final vodFavoritesProvider =
    AsyncNotifierProvider<VodFavoritesController, Set<String>>(
      VodFavoritesController.new,
    );
