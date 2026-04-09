import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_format_utils.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import 'iptv_service_providers.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entry.dart';
import 'channel_providers.dart';

/// On-demand per-channel EPG provider keyed by [Channel].
///
/// **IMPORTANT:** This provider triggers individual HTTP API calls
/// (`get_short_epg` for Xtream, `get_short_epg` for Stalker).
/// Only use in **player OSD widgets** for the single active channel.
/// Channel list items MUST use [epgProvider] batch data instead —
/// watching this from a ListView causes N concurrent API calls.
///
/// Results are cached in-memory with a smart TTL (time until
/// current show ends, minimum 5 minutes).
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

typedef ChannelProgramSnapshot =
    ({String? currentTitle, double? currentProgress, String? nextProgramLabel});

/// Channel-row/grid projection derived from batch EPG state.
///
/// This narrows rebuilds to the values each channel tile actually renders
/// instead of watching the full EPG state in every visible list/grid widget.
final channelProgramSnapshotProvider = Provider.family
    .autoDispose<ChannelProgramSnapshot, String>((ref, channelId) {
      return ref.watch(
        epgProvider.select((state) {
          final nowPlaying = state.getNowPlaying(channelId);
          final nextEntry = state.getNextProgram(channelId);
          return (
            currentTitle: nowPlaying?.title,
            currentProgress:
                nowPlaying != null && nowPlaying.isLive
                    ? nowPlaying.progress
                    : null,
            nextProgramLabel:
                nextEntry != null
                    ? 'Next: ${nextEntry.title} · '
                        '${formatHHmmLocal(nextEntry.startTime)}'
                    : null,
          );
        }),
      );
    });

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
