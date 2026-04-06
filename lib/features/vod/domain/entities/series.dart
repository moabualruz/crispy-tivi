import 'package:meta/meta.dart';

import 'vod_item.dart';

/// A TV series from a VOD source.
///
/// Domain entity — pure Dart, no infrastructure dependencies.
/// Maps to the Rust `Series` struct / `db_series` table.
@immutable
class Series {
  const Series({
    required this.id,
    required this.sourceId,
    required this.nativeId,
    required this.name,
    this.originalName,
    this.posterUrl,
    this.backdropUrl,
    this.description,
    this.year,
    this.genre,
    this.contentRating,
    this.rating,
    this.rating5based,
    this.youtubeTrailer,
    this.tmdbId,
    this.castNames,
    this.director,
    this.isAdult = false,
    this.addedAt,
    this.updatedAt,
  });

  /// Creates a [Series] from a legacy [VodItem] for gradual migration.
  factory Series.fromVodItem(VodItem item) {
    return Series(
      id: item.id,
      sourceId: item.sourceId ?? '',
      nativeId: item.id,
      name: item.name,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      description: item.description,
      year: item.year,
      rating: item.rating,
      genre: item.category,
      castNames: item.cast?.join(', '),
      director: item.director,
      addedAt: item.addedAt,
      updatedAt: item.updatedAt,
    );
  }

  /// Unique series identifier.
  final String id;

  /// Source this series belongs to.
  final String sourceId;

  /// Source-native ID.
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

  /// Release year.
  final int? year;

  /// Comma-separated genre tags.
  final String? genre;

  /// Content/parental rating (e.g. "PG-13").
  final String? contentRating;

  /// Rating string.
  final String? rating;

  /// Rating on a 5-star scale.
  final double? rating5based;

  /// YouTube trailer video ID.
  final String? youtubeTrailer;

  /// TMDB series ID.
  final int? tmdbId;

  /// Comma-separated cast / actor names.
  final String? castNames;

  /// Director name(s).
  final String? director;

  /// Whether this content is flagged as adult/NSFW.
  final bool isAdult;

  /// When the series was first imported.
  final DateTime? addedAt;

  /// When the series was last refreshed.
  final DateTime? updatedAt;

  /// Converts this [Series] back to a legacy [VodItem].
  VodItem toVodItem() {
    return VodItem(
      id: id,
      name: name,
      streamUrl: '',
      type: VodType.series,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      description: description,
      rating: rating,
      year: year,
      category: genre,
      cast: castNames?.split(', '),
      director: director,
      addedAt: addedAt,
      updatedAt: updatedAt,
      sourceId: sourceId,
    );
  }

  /// Creates a copy with optional field overrides.
  Series copyWith({
    String? id,
    String? sourceId,
    String? nativeId,
    String? name,
    String? originalName,
    String? posterUrl,
    String? backdropUrl,
    String? description,
    int? year,
    String? genre,
    String? contentRating,
    String? rating,
    double? rating5based,
    String? youtubeTrailer,
    int? tmdbId,
    String? castNames,
    String? director,
    bool? isAdult,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) {
    return Series(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      nativeId: nativeId ?? this.nativeId,
      name: name ?? this.name,
      originalName: originalName ?? this.originalName,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      description: description ?? this.description,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      contentRating: contentRating ?? this.contentRating,
      rating: rating ?? this.rating,
      rating5based: rating5based ?? this.rating5based,
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
      other is Series && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'Series($name, source=$sourceId)';
}
