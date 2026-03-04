import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/domain/entities/media_type.dart';
import '../../../vod/domain/entities/vod_item.dart';

/// Adapts a [MediaItem] from Emby/Jellyfin into a [VodItem]
/// to be compatible with UI components like `VodPosterCard`.
extension MediaItemVodAdapter on MediaItem {
  VodItem toVodItem({required String streamUrl}) {
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
      backdropUrl:
          logoUrl, // MediaServer items might not have distinct backdrops yet
      description: overview,
      rating: rating,
      year: year,
      duration: durationMs != null ? durationMs! ~/ 60000 : null,
      isFavorite:
          false, // Favorites managed differently or not at all for Media Servers yet
    );
  }
}
