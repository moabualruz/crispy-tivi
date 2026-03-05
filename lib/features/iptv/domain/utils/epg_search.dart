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
