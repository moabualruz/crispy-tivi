import '../../../player/domain/entities/watch_history_entry.dart';
import '../entities/vod_item.dart';

/// Converts a [WatchHistoryEntry] to a [VodItem] for display in
/// watch-history UI rows (Continue Watching, Cross-Device).
///
/// Placed in the VOD domain layer because the conversion produces
/// a [VodItem] — the receiving type drives the location.
extension WatchHistoryToVod on WatchHistoryEntry {
  VodItem toVodItem() {
    return VodItem(
      id: id,
      name: name,
      streamUrl: streamUrl,
      type: mediaType == 'movie' ? VodType.movie : VodType.series,
      posterUrl: posterUrl,
      backdropUrl: seriesPosterUrl, // Map it here so it's not lost
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }
}
