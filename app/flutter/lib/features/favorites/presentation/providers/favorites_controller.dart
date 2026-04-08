import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/settings_notifier.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../iptv/domain/entities/channel.dart';
import 'favorites_service_providers.dart';

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
  ///
  /// For Stalker portal channels (IDs starting with `stk_`), also
  /// pushes the change to the server via [StalkerFavoritesService]
  /// so the portal stays in sync with the local state.
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

      // Push to Stalker server if this is a Stalker channel.
      _pushStalkerFavorite(channel, remove: isFav);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Pushes a favorite toggle to the Stalker portal (fire-and-forget).
  ///
  /// Only acts when [channel.sourceId] maps to a Stalker source or
  /// the channel ID starts with `stk_`.
  void _pushStalkerFavorite(Channel channel, {required bool remove}) {
    final settings = ref.read(settingsNotifierProvider).value;
    if (settings == null) return;

    // Find the Stalker source for this channel.
    PlaylistSource? source;
    if (channel.sourceId != null) {
      source =
          settings.sources.where((s) => s.id == channel.sourceId).firstOrNull;
    }
    // Fallback: infer from ID prefix.
    if (source == null && channel.id.startsWith('stk_')) {
      source =
          settings.sources
              .where((s) => s.type == PlaylistSourceType.stalkerPortal)
              .firstOrNull;
    }
    if (source == null || source.type != PlaylistSourceType.stalkerPortal) {
      return;
    }

    ref
        .read(stalkerFavoritesServiceProvider)
        .pushFavoriteToServer(
          channelId: channel.id,
          source: source,
          remove: remove,
        );
  }

  /// Checks if a channel is favorite (synchronously
  /// from state).
  bool isFavorite(String channelId) {
    return state.value?.any((c) => c.id == channelId) ?? false;
  }
}

final favoritesControllerProvider =
    AsyncNotifierProvider.autoDispose<FavoritesController, List<Channel>>(
      FavoritesController.new,
    );
