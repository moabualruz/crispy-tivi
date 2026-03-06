import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/domain/entities/media_type.dart';
import '../../../vod/domain/entities/vod_item.dart';

/// Adapts a [MediaItem] from Emby/Jellyfin/Plex into a [VodItem]
/// to be compatible with UI components like `VodPosterCard` and
/// for sync-time persistence into the unified Rust DB.
extension MediaItemVodAdapter on MediaItem {
  VodItem toVodItem({
    required String streamUrl,
    String? sourceId,
    String? category,
  }) {
    VodType vodType;
    switch (type) {
      case MediaType.series:
      case MediaType.season:
      case MediaType.folder:
        vodType = VodType.series;
        break;
      case MediaType.episode:
        vodType = VodType.episode;
        break;
      case MediaType.movie:
      case MediaType.channel:
      case MediaType.unknown:
        vodType = VodType.movie;
        break;
    }

    return VodItem(
      id: id,
      name: name,
      streamUrl: streamUrl,
      type: vodType,
      posterUrl: logoUrl,
      backdropUrl: metadata['backdropUrl'] as String? ?? logoUrl,
      description: overview,
      rating: rating,
      year: year,
      duration: durationMs != null ? durationMs! ~/ 60000 : null,
      category: category,
      sourceId: sourceId,
      seasonNumber: metadata['parentIndex'] as int?,
      episodeNumber: metadata['index'] as int?,
      isFavorite: false,
      addedAt: DateTime.now(),
    );
  }
}
