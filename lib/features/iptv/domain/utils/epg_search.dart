import '../entities/channel.dart';
import '../entities/epg_entry.dart';

/// Returns the set of channel IDs whose currently-airing EPG
/// programme title contains [query] (case-insensitive).
///
/// [entries] is a map of channelId → list of [EpgEntry].
/// [now] defaults to [DateTime.now] when omitted (injectable
/// for deterministic tests).
Set<String> channelIdsWithMatchingLiveProgram(
  Map<String, List<EpgEntry>> entries,
  String query, {
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final lowerQuery = query.toLowerCase();
  final result = <String>{};

  for (final entry in entries.entries) {
    final channelId = entry.key;
    for (final program in entry.value) {
      if (program.isLiveAt(t) &&
          program.title.toLowerCase().contains(lowerQuery)) {
        result.add(channelId);
        break;
      }
    }
  }

  return result;
}

/// Merges EPG-matched channels into [baseList] without duplicates.
///
/// Channels already present in [baseList] are never duplicated.
/// For each channel in [allChannels] not already in [baseList],
/// the channel is included when its effective EPG id (resolved via
/// [epgOverrides] → [Channel.tvgId] → [Channel.id]) is in
/// [epgMatchIds], or when [Channel.id] itself is in [epgMatchIds].
///
/// Returns [baseList] unchanged when no extras are found.
///
/// Pure function — no framework imports, no side effects.
List<Channel> mergeEpgMatchedChannels(
  List<Channel> baseList,
  List<Channel> allChannels,
  Set<String> epgMatchIds,
  Map<String, String> epgOverrides,
) {
  final baseIds = baseList.map((c) => c.id).toSet();

  final extras =
      allChannels.where((c) {
        if (baseIds.contains(c.id)) return false;
        final effectiveId = epgOverrides[c.id] ?? c.tvgId ?? c.id;
        return epgMatchIds.contains(effectiveId) || epgMatchIds.contains(c.id);
      }).toList();

  if (extras.isEmpty) return baseList;
  return [...baseList, ...extras];
}
