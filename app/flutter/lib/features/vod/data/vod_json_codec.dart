import '../../../features/vod/domain/entities/episode.dart';
import '../../../features/vod/domain/entities/movie.dart';
import '../../../features/vod/domain/entities/season.dart';
import '../../../features/vod/domain/entities/series.dart';

/// Codec for converting VOD domain entities to/from JSON maps.
///
/// Keeps infrastructure concerns out of the domain layer.
/// All methods mirror the fields of the Rust VOD structs.
abstract final class VodJsonCodec {
  // ── Movie ──────────────────────────────────────────────────

  /// Deserializes a [Movie] from a JSON map.
  static Movie movieFromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as String,
      sourceId: json['source_id'] as String? ?? '',
      nativeId: json['native_id'] as String? ?? '',
      name: json['name'] as String,
      originalName: json['original_name'] as String?,
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      description: json['description'] as String?,
      streamUrl: json['stream_url'] as String?,
      containerExt: json['container_ext'] as String?,
      stalkerCmd: json['stalker_cmd'] as String?,
      resolvedUrl: json['resolved_url'] as String?,
      resolvedAt: json['resolved_at'] as int?,
      year: json['year'] as int?,
      durationMinutes: json['duration_minutes'] as int?,
      rating: json['rating'] as String?,
      rating5based: (json['rating_5based'] as num?)?.toDouble(),
      contentRating: json['content_rating'] as String?,
      genre: json['genre'] as String?,
      youtubeTrailer: json['youtube_trailer'] as String?,
      tmdbId: json['tmdb_id'] as int?,
      castNames: json['cast_names'] as String?,
      director: json['director'] as String?,
      isAdult: json['is_adult'] as bool? ?? false,
      addedAt:
          json['added_at'] != null
              ? DateTime.parse(json['added_at'] as String)
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
    );
  }

  /// Serializes a [Movie] to a JSON map.
  static Map<String, dynamic> movieToJson(Movie movie) {
    return {
      'id': movie.id,
      'source_id': movie.sourceId,
      'native_id': movie.nativeId,
      'name': movie.name,
      'original_name': movie.originalName,
      'poster_url': movie.posterUrl,
      'backdrop_url': movie.backdropUrl,
      'description': movie.description,
      'stream_url': movie.streamUrl,
      'container_ext': movie.containerExt,
      'stalker_cmd': movie.stalkerCmd,
      'resolved_url': movie.resolvedUrl,
      'resolved_at': movie.resolvedAt,
      'year': movie.year,
      'duration_minutes': movie.durationMinutes,
      'rating': movie.rating,
      'rating_5based': movie.rating5based,
      'content_rating': movie.contentRating,
      'genre': movie.genre,
      'youtube_trailer': movie.youtubeTrailer,
      'tmdb_id': movie.tmdbId,
      'cast_names': movie.castNames,
      'director': movie.director,
      'is_adult': movie.isAdult,
      'added_at': movie.addedAt?.toIso8601String(),
      'updated_at': movie.updatedAt?.toIso8601String(),
    };
  }

  // ── Series ─────────────────────────────────────────────────

  /// Deserializes a [Series] from a JSON map.
  static Series seriesFromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] as String,
      sourceId: json['source_id'] as String? ?? '',
      nativeId: json['native_id'] as String? ?? '',
      name: json['name'] as String,
      originalName: json['original_name'] as String?,
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      description: json['description'] as String?,
      year: json['year'] as int?,
      genre: json['genre'] as String?,
      contentRating: json['content_rating'] as String?,
      rating: json['rating'] as String?,
      rating5based: (json['rating_5based'] as num?)?.toDouble(),
      youtubeTrailer: json['youtube_trailer'] as String?,
      tmdbId: json['tmdb_id'] as int?,
      castNames: json['cast_names'] as String?,
      director: json['director'] as String?,
      isAdult: json['is_adult'] as bool? ?? false,
      addedAt:
          json['added_at'] != null
              ? DateTime.parse(json['added_at'] as String)
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
    );
  }

  /// Serializes a [Series] to a JSON map.
  static Map<String, dynamic> seriesToJson(Series series) {
    return {
      'id': series.id,
      'source_id': series.sourceId,
      'native_id': series.nativeId,
      'name': series.name,
      'original_name': series.originalName,
      'poster_url': series.posterUrl,
      'backdrop_url': series.backdropUrl,
      'description': series.description,
      'year': series.year,
      'genre': series.genre,
      'content_rating': series.contentRating,
      'rating': series.rating,
      'rating_5based': series.rating5based,
      'youtube_trailer': series.youtubeTrailer,
      'tmdb_id': series.tmdbId,
      'cast_names': series.castNames,
      'director': series.director,
      'is_adult': series.isAdult,
      'added_at': series.addedAt?.toIso8601String(),
      'updated_at': series.updatedAt?.toIso8601String(),
    };
  }

  // ── Episode ────────────────────────────────────────────────

  /// Deserializes an [Episode] from a JSON map.
  static Episode episodeFromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] as String,
      seasonId: json['season_id'] as String,
      sourceId: json['source_id'] as String? ?? '',
      nativeId: json['native_id'] as String? ?? '',
      episodeNumber: json['episode_number'] as int,
      name: json['name'] as String?,
      description: json['description'] as String?,
      posterUrl: json['poster_url'] as String?,
      streamUrl: json['stream_url'] as String?,
      containerExt: json['container_ext'] as String?,
      stalkerCmd: json['stalker_cmd'] as String?,
      resolvedUrl: json['resolved_url'] as String?,
      resolvedAt: json['resolved_at'] as int?,
      durationMinutes: json['duration_minutes'] as int?,
      airDate: json['air_date'] as String?,
      rating: json['rating'] as String?,
      contentRating: json['content_rating'] as String?,
      tmdbId: json['tmdb_id'] as int?,
      addedAt:
          json['added_at'] != null
              ? DateTime.parse(json['added_at'] as String)
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
    );
  }

  /// Serializes an [Episode] to a JSON map.
  static Map<String, dynamic> episodeToJson(Episode episode) {
    return {
      'id': episode.id,
      'season_id': episode.seasonId,
      'source_id': episode.sourceId,
      'native_id': episode.nativeId,
      'episode_number': episode.episodeNumber,
      'name': episode.name,
      'description': episode.description,
      'poster_url': episode.posterUrl,
      'stream_url': episode.streamUrl,
      'container_ext': episode.containerExt,
      'stalker_cmd': episode.stalkerCmd,
      'resolved_url': episode.resolvedUrl,
      'resolved_at': episode.resolvedAt,
      'duration_minutes': episode.durationMinutes,
      'air_date': episode.airDate,
      'rating': episode.rating,
      'content_rating': episode.contentRating,
      'tmdb_id': episode.tmdbId,
      'added_at': episode.addedAt?.toIso8601String(),
      'updated_at': episode.updatedAt?.toIso8601String(),
    };
  }

  // ── Season ─────────────────────────────────────────────────

  /// Deserializes a [Season] from a JSON map.
  static Season seasonFromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] as String,
      seriesId: json['series_id'] as String,
      seasonNumber: json['season_number'] as int,
      name: json['name'] as String?,
      posterUrl: json['poster_url'] as String?,
      episodeCount: json['episode_count'] as int?,
      airDate: json['air_date'] as String?,
    );
  }

  /// Serializes a [Season] to a JSON map.
  static Map<String, dynamic> seasonToJson(Season season) {
    return {
      'id': season.id,
      'series_id': season.seriesId,
      'season_number': season.seasonNumber,
      'name': season.name,
      'poster_url': season.posterUrl,
      'episode_count': season.episodeCount,
      'air_date': season.airDate,
    };
  }
}
