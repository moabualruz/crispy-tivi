import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/providers/active_profile_provider.dart';
import '../../../../core/providers/source_filter_provider.dart';
import '../../data/parsers/m3u_parser.dart';
import '../../domain/entities/channel.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import 'channel_list_state.dart';

export 'channel_list_state.dart';

/// Manages the channel list state — loads from M3U
/// content, filters by group, search, and toggle
/// favorites.
class ChannelListNotifier extends Notifier<ChannelListState> {
  @override
  ChannelListState build() {
    // Rebuild when source filter changes.
    ref.watch(effectiveSourceIdsProvider);

    // Listen to favorites changes and update
    // local state.
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

      // Extract unique groups (Arabic-first, then Latin, each A–Z).
      final groups = await ref
          .read(cacheServiceProvider)
          .extractSortedGroups(channels);

      // Apply initial favorites sync if available
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

  /// Navigates to the groups list view
  /// (mobile drill-down).
  void setShowGroupsView(bool show) {
    state = state.copyWith(showingGroupsView: show);
  }

  /// Filters to a specific group (null = all).
  ///
  /// Also loads any custom order for the new group.
  Future<void> selectGroup(String? group) async {
    state = state.copyWith(
      selectedGroup: group,
      clearGroup: group == null,
      isReorderMode: false,
      showingGroupsView: false,
    );
    // Load custom order for the new group.
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

  /// Loads pre-parsed channels (from any source —
  /// M3U, Xtream, etc.).
  ///
  /// Called by [PlaylistSyncService] after
  /// fetching & parsing.
  void loadChannels(List<Channel> channels, List<String> groups) {
    // Apply initial favorites sync if available
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

  /// Re-loads channels from the backend without
  /// wiping UI state.
  ///
  /// Called by the event-driven invalidator when
  /// channel data changes (e.g. [ChannelsUpdated]).
  Future<void> refreshFromBackend() async {
    try {
      final cache = ref.read(cacheServiceProvider);
      final sourceIds = ref.read(effectiveSourceIdsProvider);
      final channels =
          sourceIds.isEmpty
              ? await cache.loadChannels()
              : await cache.getChannelsBySources(sourceIds);
      final groups = await cache.extractSortedGroups(channels);
      loadChannels(channels, groups);
    } on StateError {
      // The Notifier was disposed while awaiting data loading.
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

  /// Sets the last-watched time map
  /// (for sort by watch time).
  void setLastWatchedMap(Map<String, DateTime> map) {
    state = state.copyWith(lastWatchedMap: map);
  }

  /// Sets the list of hidden groups
  /// (from settings).
  void setHiddenGroups(List<String> groups) {
    state = state.copyWith(hiddenGroups: groups.toSet());
  }

  /// Sets the hidden/blocked channel IDs
  /// (from settings).
  void setHiddenChannelIds(Set<String> ids) {
    state = state.copyWith(hiddenChannelIds: ids);
  }

  /// Toggles whether hidden channels are shown in the list.
  ///
  /// When enabled, hidden/blocked channels appear in the list
  /// so users can review and un-hide them.
  void setShowHiddenChannels(bool show) {
    state = state.copyWith(showHiddenChannels: show);
  }

  // ── Duplicate Handling ──────────────────────

  /// Sets the duplicate channel IDs.
  ///
  /// Called after playlist sync when duplicates
  /// are detected.
  void setDuplicateIds(Set<String> ids) {
    state = state.copyWith(duplicateIds: ids);
  }

  /// Toggles whether duplicate channels are
  /// hidden from the list.
  void setHideDuplicates(bool hide) {
    state = state.copyWith(hideDuplicates: hide);
  }

  // ── Channel Reordering ──────────────────────

  /// Enters or exits reorder mode.
  void setReorderMode(bool enabled) {
    state = state.copyWith(isReorderMode: enabled);
  }

  /// Reorders a channel within the current group.
  ///
  /// Called when user drags a channel from
  /// [oldIndex] to [newIndex]. Persists the new
  /// order to the database.
  Future<void> reorderChannel(int oldIndex, int newIndex) async {
    final channels = state.filteredChannels.toList();
    if (oldIndex < 0 ||
        oldIndex >= channels.length ||
        newIndex < 0 ||
        newIndex >= channels.length) {
      return;
    }

    // Move the channel in the list.
    final channel = channels.removeAt(oldIndex);
    channels.insert(newIndex, channel);

    // Get current profile ID and group name.
    final profileId = ref.read(activeProfileIdProvider);
    final groupName = state.effectiveGroup ?? '';

    // Save new order.
    final channelIds = channels.map((c) => c.id).toList();
    await ref
        .read(cacheServiceProvider)
        .saveChannelOrder(profileId, groupName, channelIds);

    // Update state with new order map.
    final orderMap = <String, int>{};
    for (int i = 0; i < channelIds.length; i++) {
      orderMap[channelIds[i]] = i;
    }
    state = state.copyWith(customOrderMap: orderMap);
  }

  /// Resets to default sort order for the current
  /// group.
  ///
  /// Deletes any custom order and reverts to
  /// number/alphabetical sort.
  Future<void> resetToDefaultOrder() async {
    final profileId = ref.read(activeProfileIdProvider);
    final groupName = state.effectiveGroup ?? '';

    await ref
        .read(cacheServiceProvider)
        .resetChannelOrder(profileId, groupName);

    state = state.copyWith(clearCustomOrder: true);
  }

  /// Loads custom order for the current group
  /// from database.
  ///
  /// Called when group changes or on initial load.
  Future<void> loadCustomOrder() async {
    final profileId = ref.read(activeProfileIdProvider);
    final groupName = state.effectiveGroup ?? '';

    final orderMap = await ref
        .read(cacheServiceProvider)
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

/// Derived provider for unique channel groups.
final channelGroupsProvider = Provider<List<String>>((ref) {
  return ref.watch(channelListProvider).groups;
});

/// Derived provider for the current search query.
final channelSearchQueryProvider = Provider<String>((ref) {
  return ref.watch(channelListProvider).searchQuery;
});

/// Private async provider that calls the backend for
/// EPG-aware channel search (FE-TV-05).
///
/// Chains [searchChannelsByLiveProgram] → [mergeEpgMatchedChannels].
/// Returns null when no search is active (caller falls back to
/// [ChannelListState.filteredChannels]).
final _epgAwareChannelListAsyncProvider =
    FutureProvider.autoDispose<List<Channel>?>((ref) async {
      final channelState = ref.watch(channelListProvider);
      final query = channelState.searchQuery;

      // No search active — no async work needed.
      if (query.isEmpty) return null;

      final epgState = ref.watch(epgProvider);
      final cache = ref.read(cacheServiceProvider);
      final now = DateTime.now();

      // Step 1: find channel IDs whose live program matches query.
      final matchedIds = await cache.searchChannelsByLiveProgram(
        epgState.entries,
        query,
        now.millisecondsSinceEpoch,
      );

      if (matchedIds.isEmpty) return channelState.filteredChannels;

      // Step 2: merge matched channels into base filtered list.
      return cache.mergeEpgMatchedChannels(
        baseChannels: channelState.filteredChannels,
        allChannels: channelState.channels,
        matchedIds: matchedIds,
        epgOverrides: epgState.epgOverrides,
      );
    });

/// EPG-aware channel list provider (FE-TV-05).
///
/// When a search query is active, extends the standard
/// [channelListProvider.filteredChannels] result by also
/// including channels whose currently-airing EPG program
/// title matches the query — even if the channel name does
/// not match.
///
/// Example: typing "News" returns channels named "News"
/// AND channels that are currently airing a program whose
/// title contains "News".
///
/// When the query is empty, returns the same list as
/// [ChannelListState.filteredChannels] with no overhead.
/// Falls back to [ChannelListState.filteredChannels] while
/// the async backend call is pending.
final epgAwareChannelListProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channelState = ref.watch(channelListProvider);
  final query = channelState.searchQuery;

  // No search active — return standard filtered list immediately.
  if (query.isEmpty) return channelState.filteredChannels;

  // Use backend result when ready; fall back to filtered list while pending.
  return ref.watch(_epgAwareChannelListAsyncProvider).value ??
      channelState.filteredChannels;
});
