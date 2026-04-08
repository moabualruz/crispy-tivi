import 'package:meta/meta.dart';

import 'vod_item.dart';

/// A standalone movie from a VOD source.
///
/// Domain entity — pure Dart, no infrastructure dependencies.
/// Maps to the Rust `Movie` struct / `db_movies` table.
@immutable
class Movie {
  const Movie({
    required this.id,
    required this.sourceId,
    required this.nativeId,
    required this.name,
    this.originalName,
    this.posterUrl,
    this.backdropUrl,
    this.description,
    this.streamUrl,
    this.containerExt,
    this.stalkerCmd,
    this.resolvedUrl,
    this.resolvedAt,
    this.year,
    this.durationMinutes,
    this.rating,
    this.rating5based,
    this.contentRating,
    this.genre,
    this.youtubeTrailer,
    this.tmdbId,
    this.castNames,
    this.director,
    this.isAdult = false,
    this.addedAt,
    this.updatedAt,
  });

  /// Creates a [Movie] from a legacy [VodItem] for gradual migration.
  factory Movie.fromVodItem(VodItem item) {
    return Movie(
      id: item.id,
      sourceId: item.sourceId ?? '',
      nativeId: item.id,
      name: item.name,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      description: item.description,
      streamUrl: item.streamUrl,
      containerExt: item.extension,
      year: item.year,
      durationMinutes: item.duration,
      rating: item.rating,
      genre: item.category,
      castNames: item.cast?.join(', '),
      director: item.director,
      addedAt: item.addedAt,
      updatedAt: item.updatedAt,
    );
  }

  /// Unique movie identifier.
  final String id;

  /// Source this movie belongs to.
  final String sourceId;

  /// Source-native ID (stream_id for Xtream, portal id for Stalker).
  final String nativeId;

  /// Display name / title.
  final String name;

  /// Original/alternate title.
  final String? originalName;

  /// URL of the poster image.
  final String? posterUrl;

  /// URL of the backdrop / fanart image.
  final String? backdropUrl;

  /// Synopsis / plot description.
  final String? description;

  /// Direct stream URL.
  final String? streamUrl;

  /// Container extension (e.g. "mkv", "mp4").
  final String? containerExt;

  /// Raw Stalker cmd for re-resolution.
  final String? stalkerCmd;

  /// Resolved URL from cmd.
  final String? resolvedUrl;

  /// Epoch when resolved.
  final int? resolvedAt;

  /// Release year.
  final int? year;

  /// Duration in minutes.
  final int? durationMinutes;

  /// Rating string (e.g. "7.5").
  final String? rating;

  /// Rating on a 5-star scale.
  final double? rating5based;

  /// Content/parental rating (e.g. "PG-13", "R").
  final String? contentRating;

  /// Comma-separated genre tags.
  final String? genre;

  /// YouTube trailer video ID.
  final String? youtubeTrailer;

  /// TMDB movie ID.
  final int? tmdbId;

  /// Comma-separated cast / actor names.
  final String? castNames;

  /// Director name(s).
  final String? director;

  /// Whether this content is flagged as adult/NSFW.
  final bool isAdult;

  /// When the movie was first imported.
  final DateTime? addedAt;

  /// When the movie was last refreshed.
  final DateTime? updatedAt;

  /// Converts this [Movie] back to a legacy [VodItem].
  VodItem toVodItem() {
    return VodItem(
      id: id,
      name: name,
      streamUrl: streamUrl ?? '',
      type: VodType.movie,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      description: description,
      rating: rating,
      year: year,
      duration: durationMinutes,
      category: genre,
      cast: castNames?.split(', '),
      director: director,
      extension: containerExt,
      addedAt: addedAt,
      updatedAt: updatedAt,
      sourceId: sourceId,
    );
  }

  /// Creates a copy with optional field overrides.
  Movie copyWith({
    String? id,
    String? sourceId,
    String? nativeId,
    String? name,
    String? originalName,
    String? posterUrl,
    String? backdropUrl,
    String? description,
    String? streamUrl,
    String? containerExt,
    String? stalkerCmd,
    String? resolvedUrl,
    int? resolvedAt,
    int? year,
    int? durationMinutes,
    String? rating,
    double? rating5based,
    String? contentRating,
    String? genre,
    String? youtubeTrailer,
    int? tmdbId,
    String? castNames,
    String? director,
    bool? isAdult,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) {
    return Movie(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      nativeId: nativeId ?? this.nativeId,
      name: name ?? this.name,
      originalName: originalName ?? this.originalName,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      description: description ?? this.description,
      streamUrl: streamUrl ?? this.streamUrl,
      containerExt: containerExt ?? this.containerExt,
      stalkerCmd: stalkerCmd ?? this.stalkerCmd,
      resolvedUrl: resolvedUrl ?? this.resolvedUrl,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      year: year ?? this.year,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      rating: rating ?? this.rating,
      rating5based: rating5based ?? this.rating5based,
      contentRating: contentRating ?? this.contentRating,
      genre: genre ?? this.genre,
      youtubeTrailer: youtubeTrailer ?? this.youtubeTrailer,
      tmdbId: tmdbId ?? this.tmdbId,
      castNames: castNames ?? this.castNames,
      director: director ?? this.director,
      isAdult: isAdult ?? this.isAdult,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Movie && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'Movie($name, source=$sourceId)';
}
