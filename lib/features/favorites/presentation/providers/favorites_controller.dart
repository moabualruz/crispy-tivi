import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../profiles/data/profile_service.dart';
import '../../data/repositories/favorites_repository_impl.dart';

/// Manages the list of favorite channels for the
/// active profile.
class FavoritesController extends AsyncNotifier<List<Channel>> {
  @override
  Future<List<Channel>> build() async {
    // Rebuild when active profile loads or switches.
    ref.watch(profileServiceProvider);
    final repo = ref.watch(favoritesRepositoryProvider);
    return repo.getFavorites();
  }

  /// Toggles the favorite status of a channel.
  Future<void> toggleFavorite(Channel channel) async {
    final repo = ref.read(favoritesRepositoryProvider);
    final currentList = state.value ?? [];
    final isFav = currentList.any((c) => c.id == channel.id);

    state = const AsyncLoading();

    try {
      if (isFav) {
        await repo.removeFavorite(channel.id);
        final updated = currentList.where((c) => c.id != channel.id).toList();
        state = AsyncData(updated);
      } else {
        await repo.addFavorite(channel);
        final updated = [...currentList, channel.copyWith(isFavorite: true)];
        state = AsyncData(updated);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Checks if a channel is favorite (synchronously
  /// from state).
  bool isFavorite(String channelId) {
    return state.value?.any((c) => c.id == channelId) ?? false;
  }
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<Channel>>(
      FavoritesController.new,
    );
