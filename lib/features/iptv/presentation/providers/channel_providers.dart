import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/active_profile_provider.dart';
import '../../../../core/providers/source_filter_provider.dart';
import 'iptv_service_providers.dart' show crispyBackendProvider;
import '../../data/channel_repository_impl.dart'
    show channelRepositoryProvider, channelOrderRepositoryProvider;
import '../../data/parsers/m3u_parser.dart';
import '../../domain/entities/channel.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import 'channel_list_state.dart';

export 'channel_list_state.dart';
export 'channel_derived_providers.dart';
export 'channel_reorder_actions.dart';

/// Manages the channel list state — loads from M3U
/// content, filters by group, search, and toggle
/// favorites.
class ChannelListNotifier extends Notifier<ChannelListState> {
  @override
  ChannelListState build() {
    ref.watch(effectiveSourceIdsProvider);

    ref.listen(favoritesControllerProvider, (prev, next) {
      final favs = next.asData?.value;
      if (favs != null) {
        _syncFavorites(favs);
      }
    });
    return const ChannelListState();
  }

  void _syncFavorites(List<Channel> favs) {
    if (state.channels.isEmpty) return;

    final favIds = favs.map((c) => c.id).toSet();
    final updated =
        state.channels.map((c) {
          final isFav = favIds.contains(c.id);
          if (c.isFavorite != isFav) {
            return c.copyWith(isFavorite: isFav);
          }
          return c;
        }).toList();

    state = state.copyWith(channels: updated);
  }

  /// Loads channels from raw M3U content.
  Future<void> loadFromM3u(String content) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final backend = ref.read(crispyBackendProvider);
      final parsed = await M3uParser.parseInIsolate(content, backend);
      final channels = parsed.channels;

      final groups = await ref
          .read(channelOrderRepositoryProvider)
          .extractSortedGroups(channels);

      List<Channel> finalChannels = channels;
      final favs = ref.read(favoritesControllerProvider).asData?.value;
      if (favs != null) {
        final favIds = favs.map((c) => c.id).toSet();
        finalChannels =
            channels
                .map((c) => c.copyWith(isFavorite: favIds.contains(c.id)))
                .toList();
      }

      state = state.copyWith(
        channels: finalChannels,
        groups: groups,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Navigates to the groups list view (mobile drill-down).
  void setShowGroupsView(bool show) {
    state = state.copyWith(showingGroupsView: show);
  }

  /// Filters to a specific group (null = all).
  Future<void> selectGroup(String? group) async {
    state = state.copyWith(
      selectedGroup: group,
      clearGroup: group == null,
      isReorderMode: false,
      showingGroupsView: false,
    );
    await loadCustomOrder();
  }

  /// Sets the channel sort mode.
  void setSortMode(ChannelSortMode mode) {
    state = state.copyWith(
      sortMode: mode,
      isReorderMode: mode == ChannelSortMode.manual,
    );
  }

  /// Updates the search query for live filtering.
  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Toggles favorite status for a channel.
  Future<void> toggleFavorite(String channelId) async {
    final channel = state.channels.firstWhereOrNull((c) => c.id == channelId);
    if (channel == null) return;
    await ref
        .read(favoritesControllerProvider.notifier)
        .toggleFavorite(channel);
  }

  /// Loads pre-parsed channels (from any source — M3U, Xtream, etc.).
  void loadChannels(List<Channel> channels, List<String> groups) {
    List<Channel> finalChannels = channels;
    final favs = ref.read(favoritesControllerProvider).asData?.value;
    if (favs != null) {
      final favIds = favs.map((c) => c.id).toSet();
      finalChannels =
          channels
              .map((c) => c.copyWith(isFavorite: favIds.contains(c.id)))
              .toList();
    }

    state = state.copyWith(
      channels: finalChannels,
      groups: groups,
      isLoading: false,
      clearError: true,
    );
  }

  /// Re-loads channels from the backend without wiping UI state.
  Future<void> refreshFromBackend() async {
    try {
      final repo = ref.read(channelRepositoryProvider);
      final sourceIds = ref.read(effectiveSourceIdsProvider);
      final channels =
          sourceIds.isEmpty
              ? await repo.loadChannels()
              : await repo.getChannelsBySources(sourceIds);
      final groups = await ref
          .read(channelOrderRepositoryProvider)
          .extractSortedGroups(channels);
      loadChannels(channels, groups);
    } on StateError {
      return;
    }
  }

  /// Sets the channel grouping mode.
  void setGroupMode(ChannelGroupMode mode) {
    state = state.copyWith(
      groupMode: mode,
      clearGroup: true,
      showingGroupsView: true,
    );
  }

  /// Sets the playlist source names map.
  void setSourceNames(Map<String, String> names) {
    state = state.copyWith(sourceNames: names);
  }

  /// Sets the last-watched time map (for sort by watch time).
  void setLastWatchedMap(Map<String, DateTime> map) {
    state = state.copyWith(lastWatchedMap: map);
  }

  /// Sets the list of hidden groups (from settings).
  void setHiddenGroups(List<String> groups) {
    state = state.copyWith(hiddenGroups: groups.toSet());
  }

  /// Sets the hidden/blocked channel IDs (from settings).
  void setHiddenChannelIds(Set<String> ids) {
    state = state.copyWith(hiddenChannelIds: ids);
  }

  /// Toggles whether hidden channels are shown in the list.
  void setShowHiddenChannels(bool show) {
    state = state.copyWith(showHiddenChannels: show);
  }

  /// Sets the duplicate channel IDs.
  void setDuplicateIds(Set<String> ids) {
    state = state.copyWith(duplicateIds: ids);
  }

  /// Toggles whether duplicate channels are hidden from the list.
  void setHideDuplicates(bool hide) {
    state = state.copyWith(hideDuplicates: hide);
  }

  /// Enters or exits reorder mode.
  void setReorderMode(bool enabled) {
    state = state.copyWith(isReorderMode: enabled);
  }

  /// Loads custom order for the current group from database.
  ///
  /// Called when group changes or on initial load.
  /// Also available via [ChannelReorderActions] extension.
  Future<void> loadCustomOrder() async {
    final profileId = ref.read(activeProfileIdProvider);
    final groupName = state.effectiveGroup ?? '';

    final orderMap = await ref
        .read(channelOrderRepositoryProvider)
        .loadChannelOrder(profileId, groupName);

    state = state.copyWith(
      customOrderMap: orderMap,
      clearCustomOrder: orderMap == null,
    );
  }
}

/// Global provider for channel list state.
final channelListProvider =
    NotifierProvider<ChannelListNotifier, ChannelListState>(
      ChannelListNotifier.new,
    );
