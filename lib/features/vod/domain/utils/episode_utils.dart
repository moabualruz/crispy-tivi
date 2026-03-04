import 'package:crispy_tivi/core/constants.dart';

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
