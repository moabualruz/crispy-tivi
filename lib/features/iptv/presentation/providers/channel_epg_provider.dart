import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../epg/presentation/providers/epg_providers.dart';
import '../../data/channel_epg_fetcher.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entry.dart';
import 'channel_providers.dart';

/// On-demand per-channel EPG provider keyed by [Channel].
///
/// Fetches current and upcoming EPG data from the channel's source
/// API (Xtream `get_short_epg` or Stalker `get_short_epg`).
///
/// Results are cached in-memory with a 5-minute TTL. The provider
/// auto-disposes when the widget that watches it unmounts, but the
/// in-memory cache persists across provider rebuilds so re-entering
/// a screen does not re-fetch immediately.
final channelEpgProvider = FutureProvider.family
    .autoDispose<List<EpgEntry>, Channel>((ref, channel) async {
      return fetchChannelEpg(ref, channel);
    });

/// On-demand per-channel EPG provider keyed by channel ID (String).
///
/// Looks up the [Channel] from the channel list state, then delegates
/// to [fetchChannelEpg]. Designed for widgets like [LiveEpgStrip] and
/// [OsdMiniGuide] that only have a channel ID string available.
///
/// Returns an empty list if the channel ID is not found in the
/// current channel list.
final channelEpgByIdProvider = FutureProvider.family
    .autoDispose<List<EpgEntry>, String>((ref, channelId) async {
      final channelListState = ref.read(channelListProvider);
      final channel = _findChannelById(channelListState.channels, channelId);
      if (channel == null) return const [];
      return fetchChannelEpg(ref, channel);
    });

/// Returns the best available "now playing" EPG entry for a channel.
///
/// Prefers on-demand data (fresher) over batch XMLTV data. Falls back
/// to the global [epgProvider] state when on-demand data is unavailable
/// or still loading.
///
/// This is the single source of truth for "what is airing now" that
/// should be used by channel list items, the OSD, and the mini-guide.
EpgEntry? bestNowPlaying(WidgetRef ref, Channel channel) {
  // Try on-demand data first (may be loading or unavailable).
  final onDemand = ref.watch(channelEpgProvider(channel));
  final onDemandEntries = onDemand.asData?.value;

  // Try batch XMLTV data.
  final epgState = ref.watch(epgProvider);
  final batchEntry = epgState.getNowPlaying(channel.id);

  if (onDemandEntries != null && onDemandEntries.isNotEmpty) {
    final now = DateTime.now().toUtc();
    for (final e in onDemandEntries) {
      if (e.isLiveAt(now)) return e;
    }
  }

  // Fall back to batch XMLTV data.
  return batchEntry;
}

/// Returns the best available "next" EPG entry for a channel.
///
/// Same freshness logic as [bestNowPlaying].
EpgEntry? bestNextProgram(WidgetRef ref, Channel channel) {
  final onDemand = ref.watch(channelEpgProvider(channel));
  final onDemandEntries = onDemand.asData?.value;

  final epgState = ref.watch(epgProvider);
  final batchNext = epgState.getNextProgram(channel.id);

  if (onDemandEntries != null && onDemandEntries.isNotEmpty) {
    final now = DateTime.now().toUtc();
    EpgEntry? liveEntry;
    for (final e in onDemandEntries) {
      if (e.isLiveAt(now)) {
        liveEntry = e;
        break;
      }
    }
    if (liveEntry != null) {
      for (final e in onDemandEntries) {
        if (e.startTime.isAfter(liveEntry.startTime) &&
            !e.startTime.isBefore(liveEntry.endTime)) {
          return e;
        }
      }
    }
  }

  return batchNext;
}

/// Returns the best available "now playing" EPG entry by channel ID.
///
/// For use in player OSD widgets that only have the channel ID string.
/// Same freshness logic as [bestNowPlaying].
EpgEntry? bestNowPlayingById(WidgetRef ref, String channelId) {
  final onDemand = ref.watch(channelEpgByIdProvider(channelId));
  final onDemandEntries = onDemand.asData?.value;

  final epgState = ref.watch(epgProvider);
  final batchEntry = epgState.getNowPlaying(channelId);

  if (onDemandEntries != null && onDemandEntries.isNotEmpty) {
    final now = DateTime.now().toUtc();
    for (final e in onDemandEntries) {
      if (e.isLiveAt(now)) return e;
    }
  }

  return batchEntry;
}

/// Returns the best available "next" EPG entry by channel ID.
///
/// For use in player OSD widgets that only have the channel ID string.
EpgEntry? bestNextProgramById(WidgetRef ref, String channelId) {
  final onDemand = ref.watch(channelEpgByIdProvider(channelId));
  final onDemandEntries = onDemand.asData?.value;

  final epgState = ref.watch(epgProvider);
  final batchNext = epgState.getNextProgram(channelId);

  if (onDemandEntries != null && onDemandEntries.isNotEmpty) {
    final now = DateTime.now().toUtc();
    EpgEntry? liveEntry;
    for (final e in onDemandEntries) {
      if (e.isLiveAt(now)) {
        liveEntry = e;
        break;
      }
    }
    if (liveEntry != null) {
      for (final e in onDemandEntries) {
        if (e.startTime.isAfter(liveEntry.startTime) &&
            !e.startTime.isBefore(liveEntry.endTime)) {
          return e;
        }
      }
    }
  }

  return batchNext;
}

/// Looks up a channel by ID in the channel list.
Channel? _findChannelById(List<Channel> channels, String channelId) {
  for (final ch in channels) {
    if (ch.id == channelId) return ch;
  }
  return null;
}
