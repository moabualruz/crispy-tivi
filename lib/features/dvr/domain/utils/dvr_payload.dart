import 'dart:convert';

import '../entities/recording.dart';

/// Serialises [recordings] into the JSON string expected by the
/// Rust `get_recordings_to_start` handler.
///
/// Each entry is a minimal map with `id`, `status`, `startTime`,
/// and `endTime` (epoch-ms integers).
String buildRecordingsCheckJson(List<Recording> recordings) {
  return jsonEncode(
    recordings
        .map(
          (r) => {
            'id': r.id,
            'status': r.status.name,
            'startTime': r.startTime.millisecondsSinceEpoch,
            'endTime': r.endTime.millisecondsSinceEpoch,
          },
        )
        .toList(),
  );
}

/// Returns the IDs of series items whose [updatedAt] is more recent
/// than [days] days before [now].
///
/// [series] is a list of records exposing `id` and `updatedAt`.
/// [now] defaults to [DateTime.now] when omitted (injectable for
/// deterministic tests).
Set<String> seriesIdsWithNewEpisodes(
  List<({String id, DateTime? updatedAt})> series, {
  DateTime? now,
  int days = 14,
}) {
  final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
  return {
    for (final s in series)
      if (s.updatedAt != null && s.updatedAt!.isAfter(cutoff)) s.id,
  };
}

/// Returns the count of in-progress episodes for [seriesId].
///
/// An episode is "in progress" when its duration is known, it has
/// been started, and it has not yet reached the completion threshold.
///
/// [entries] is a list of watch-history-like records.
int countInProgressEpisodesForSeries(
  List<
    ({
      String? seriesId,
      String mediaType,
      int durationMs,
      bool isNearlyComplete,
    })
  >
  entries,
  String seriesId,
) {
  var count = 0;
  for (final entry in entries) {
    if (entry.seriesId == seriesId &&
        entry.mediaType == 'episode' &&
        entry.durationMs > 0 &&
        !entry.isNearlyComplete) {
      count++;
    }
  }
  return count;
}
