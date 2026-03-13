import '../../../../core/utils/date_format_utils.dart';
import '../entities/recording.dart';

/// Canonical serialiser for a [Recording] to the snake_case map
/// expected by all Rust handlers.
///
/// This is the **single source of truth** for Recording → Map
/// conversion. Every field on [Recording] is included so that
/// both the persistence layer ([CacheService]) and the algorithm
/// layer (conflict detection, recurring expansion) use an
/// identical representation.
Map<String, dynamic> recordingToMap(Recording r) {
  return {
    'id': r.id,
    'channel_id': r.channelId,
    'channel_name': r.channelName,
    'channel_logo_url': r.channelLogoUrl,
    'program_name': r.programName,
    'stream_url': r.streamUrl,
    'start_time': toNaiveDateTime(r.startTime),
    'end_time': toNaiveDateTime(r.endTime),
    'status': r.status.name,
    'file_path': r.filePath,
    'file_size_bytes': r.fileSizeBytes,
    'is_recurring': r.isRecurring,
    'recur_days': r.recurDays,
    'profile': r.profile.name,
    'owner_profile_id': r.ownerProfileId,
    'is_shared': r.isShared,
    'remote_backend_id': r.remoteBackendId,
    'remote_path': r.remotePath,
    'auto_delete_policy': r.autoDeletePolicy.name,
    'keep_episode_count': r.keepEpisodeCount,
  };
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
