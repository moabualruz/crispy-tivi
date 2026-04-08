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

    // Extract cast from metadata (List<String> or null).
    final rawCast = metadata['cast'];
    final cast = rawCast is List ? rawCast.cast<String>().toList() : null;

    // Extract director from metadata (String or null).
    final director = metadata['director'] as String?;

    // Extract genres from metadata for category fallback.
    final rawGenres = metadata['genres'];
    final genres = rawGenres is List ? rawGenres.cast<String>().toList() : null;

    // Use explicit category, or fall back to first genre if available.
    final resolvedCategory =
        category ?? (genres != null && genres.isNotEmpty ? genres.first : null);

    // Extract favorite status from metadata.
    final isFavorite = metadata['isFavorite'] as bool? ?? false;

    // Extract series hierarchy metadata.
    final seriesId = metadata['seriesId'] as String?;
    final seasonCount = metadata['seasonCount'] as int?;

    // Extract container format for file extension.
    final container = metadata['container'] as String?;

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
      category: resolvedCategory,
      sourceId: sourceId,
      seasonNumber: metadata['parentIndex'] as int?,
      episodeNumber: metadata['index'] as int?,
      isFavorite: isFavorite,
      addedAt: DateTime.now(),
      cast: cast,
      director: director,
      seriesId: seriesId,
      seasonCount: seasonCount,
      extension: container,
    );
  }
}
