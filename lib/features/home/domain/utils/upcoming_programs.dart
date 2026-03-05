import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';

/// A single upcoming programme entry shown in the home screen.
class UpcomingProgram {
  const UpcomingProgram({required this.channel, required this.entry});

  /// The favourite channel this programme airs on.
  final Channel channel;

  /// The upcoming EPG entry.
  final EpgEntry entry;
}

/// Filters EPG entries across [favorites] to find programmes that
/// start within [window] of [now], sorted by start time ascending,
/// capped at [limit].
///
/// [entriesForChannel] is a lookup function that takes a channel
/// EPG key and returns its [EpgEntry] list.
/// [now] defaults to `DateTime.now().toUtc()` when omitted
/// (injectable for deterministic tests).
List<UpcomingProgram> filterUpcomingPrograms(
  List<EpgEntry> Function(String channelKey) entriesForChannel,
  List<Channel> favorites, {
  DateTime? now,
  Duration window = const Duration(minutes: 120),
  int limit = 20,
}) {
  final t = now?.toUtc() ?? DateTime.now().toUtc();
  final cutoff = t.add(window);
  final results = <UpcomingProgram>[];

  for (final channel in favorites) {
    final epgKey = channel.tvgId ?? channel.id;
    final channelEntries = entriesForChannel(epgKey);
    for (final entry in channelEntries) {
      if (entry.startTime.isAfter(t) && entry.startTime.isBefore(cutoff)) {
        results.add(UpcomingProgram(channel: channel, entry: entry));
      }
    }
  }

  results.sort((a, b) => a.entry.startTime.compareTo(b.entry.startTime));
  return results.take(limit).toList();
}
