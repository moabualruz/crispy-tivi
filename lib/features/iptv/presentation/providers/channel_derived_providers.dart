import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../epg/presentation/providers/epg_providers.dart';
import 'iptv_service_providers.dart';
import '../../domain/entities/channel.dart';
import 'channel_providers.dart';

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
      final repo = ref.read(channelRepositoryProvider);
      final now = DateTime.now();

      // Step 1: find channel IDs whose live program matches query.
      final matchedIds = await repo.searchChannelsByLiveProgram(
        epgState.entries,
        query,
        now.millisecondsSinceEpoch,
      );

      if (matchedIds.isEmpty) return channelState.filteredChannels;

      // Step 2: merge matched channels into base filtered list.
      return repo.mergeEpgMatchedChannels(
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
