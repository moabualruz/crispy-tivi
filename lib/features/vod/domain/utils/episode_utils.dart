import 'dart:convert';

import 'package:crispy_tivi/core/constants.dart';

import '../../../player/domain/entities/watch_history_entry.dart';
import '../entities/vod_item.dart';

/// Finds the next unwatched episode and whether all episodes are completed.
///
/// Returns a record with the next episode to play and whether the user
/// has watched all episodes (replay mode).
({VodItem? next, bool isReplay}) findNextEpisode(
  List<VodItem> episodes,
  Map<String, double> progressMap,
) {
  VodItem? next;
  for (final ep in episodes) {
    final progress = progressMap[ep.streamUrl] ?? 0.0;
    if (progress < kCompletionThreshold) {
      next = ep;
      break;
    }
  }

  next ??= episodes.isNotEmpty ? episodes.first : null;

  final isReplay =
      progressMap.isNotEmpty &&
      progressMap.values.every((p) => p >= kCompletionThreshold);

  return (next: next, isReplay: isReplay);
}

// ── Next-episode auto-queue threshold ───────────────────
//
// When an episode's progress meets or exceeds this value,
// the Continue Watching row shows the NEXT episode instead
// of the nearly-completed one. Set lower than
// [kCompletionThreshold] (0.95) so the card switches before
// the backend removes the entry from the continue-watching
// list.
const double kNextEpisodeThreshold = 0.90;

/// Resolves the next unplayed episode for series entries that
/// are >= 90% complete.
///
/// For each entry in [entries]:
/// - Progress < 90% → kept as-is.
/// - Progress >= 90% → look up the series' episode list in
///   [allVodItems] and substitute the next sequential episode
///   (next by episode number within the same or next season).
/// - If no next episode is found (series complete), the
///   original entry is kept.
///
/// The returned list preserves the original sort order.
List<WatchHistoryEntry> resolveNextEpisodes(
  List<WatchHistoryEntry> entries,
  List<VodItem> allVodItems,
) {
  return entries.map((entry) {
    if (entry.mediaType != 'episode') return entry;
    if (entry.durationMs <= 0) return entry;
    final progress = entry.progress;
    if (progress < kNextEpisodeThreshold) return entry;

    final seriesId = entry.seriesId;
    final season = entry.seasonNumber;
    final episode = entry.episodeNumber;
    if (seriesId == null || season == null || episode == null) return entry;

    // Gather all episodes for this series, sorted by season then episode.
    final seriesEpisodes =
        allVodItems
            .where(
              (v) =>
                  v.type == VodType.episode &&
                  v.seriesId == seriesId &&
                  v.seasonNumber != null &&
                  v.episodeNumber != null,
            )
            .toList()
          ..sort((a, b) {
            final sc = a.seasonNumber!.compareTo(b.seasonNumber!);
            return sc != 0 ? sc : a.episodeNumber!.compareTo(b.episodeNumber!);
          });

    if (seriesEpisodes.isEmpty) return entry;

    // Find the current episode index and advance by one.
    final currentIdx = seriesEpisodes.indexWhere(
      (v) => v.seasonNumber == season && v.episodeNumber == episode,
    );
    if (currentIdx == -1 || currentIdx + 1 >= seriesEpisodes.length) {
      // No next episode — series complete; keep original.
      return entry;
    }

    final next = seriesEpisodes[currentIdx + 1];

    // Return a new entry describing the next episode so the
    // Continue Watching card shows the upcoming episode's
    // metadata (title, thumbnail, episode numbers).
    return WatchHistoryEntry(
      id: next.id,
      mediaType: 'episode',
      name: next.name,
      streamUrl: next.streamUrl,
      posterUrl: next.posterUrl ?? entry.posterUrl,
      seriesPosterUrl: entry.seriesPosterUrl,
      positionMs: 0,
      durationMs: 0,
      lastWatched: entry.lastWatched,
      seriesId: next.seriesId,
      seasonNumber: next.seasonNumber,
      episodeNumber: next.episodeNumber,
      deviceId: entry.deviceId,
      deviceName: entry.deviceName,
      profileId: entry.profileId,
    );
  }).toList();
}

/// Builds a map of season number → episode count from [allEpisodes].
///
/// Used to display episode counts in the season selector dropdown
/// (FE-SRD-04).
Map<int, int> episodeCountBySeason(List<VodItem> allEpisodes) {
  final counts = <int, int>{};
  for (final ep in allEpisodes) {
    final s = ep.seasonNumber;
    if (s != null) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
  }
  return counts;
}

/// Computes the index of the "up next" episode in [filtered].
///
/// Up next = the episode immediately after the last-watched
/// episode. [lastId] is the stream URL of the last-watched
/// episode. Returns -1 when there is no last-watched episode
/// or it is the final episode in the list.
int upNextIndex(
  List<VodItem> filtered,
  Map<String, double> pMap,
  String? lastId,
) {
  if (lastId == null || filtered.isEmpty) return -1;
  final lastIdx = filtered.indexWhere((e) => e.streamUrl == lastId);
  if (lastIdx < 0 || lastIdx >= filtered.length - 1) return -1;
  return lastIdx + 1;
}

/// Decodes the JSON payload returned by
/// `CrispyBackend.computeEpisodeProgressFromDb` into a typed record.
///
/// Expected JSON shape:
/// ```json
/// { "progress_map": { "<streamUrl>": <double> }, "last_watched_url": "<url>" }
/// ```
///
/// Returns a record with:
/// - [progressMap] — map of stream URL → progress fraction (0.0–1.0).
/// - [lastWatchedUrl] — stream URL of the most-recently-watched episode,
///   or `null` when none exists.
///
/// Pure function — no framework imports, no side effects.
({Map<String, double> progressMap, String? lastWatchedUrl})
decodeEpisodeProgress(String resultJson) {
  final result = jsonDecode(resultJson) as Map<String, dynamic>;
  final progressMap = (result['progress_map'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, (v as num).toDouble()),
  );
  final lastWatchedUrl = result['last_watched_url'] as String?;
  return (progressMap: progressMap, lastWatchedUrl: lastWatchedUrl);
}
