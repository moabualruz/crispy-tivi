import 'dart:convert';

/// Decodes the JSON payload returned by
/// `CrispyBackend.computeEpisodeProgressFromDb` into a typed record.
///
/// Expected JSON shape:
/// ```json
/// { "progress_map": { "<streamUrl>": <double> }, "last_watched_url": "<url>" }
/// ```
///
/// Returns a record with:
/// - [progressMap] -- map of stream URL to progress fraction (0.0-1.0).
/// - [lastWatchedUrl] -- stream URL of the most-recently-watched episode,
///   or `null` when none exists.
///
/// Lives in data layer because it uses `dart:convert`.
({Map<String, double> progressMap, String? lastWatchedUrl})
decodeEpisodeProgress(String resultJson) {
  final result = jsonDecode(resultJson) as Map<String, dynamic>;
  final progressMap = (result['progress_map'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, (v as num).toDouble()),
  );
  final lastWatchedUrl = result['last_watched_url'] as String?;
  return (progressMap: progressMap, lastWatchedUrl: lastWatchedUrl);
}
