import 'package:flutter/foundation.dart';

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

  /// Creates a [Series] from a JSON map (for future FFI integration).
  factory Series.fromJson(Map<String, dynamic> json) {
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

  /// Serializes this [Series] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'native_id': nativeId,
      'name': name,
      'original_name': originalName,
      'poster_url': posterUrl,
      'backdrop_url': backdropUrl,
      'description': description,
      'year': year,
      'genre': genre,
      'content_rating': contentRating,
      'rating': rating,
      'rating_5based': rating5based,
      'youtube_trailer': youtubeTrailer,
      'tmdb_id': tmdbId,
      'cast_names': castNames,
      'director': director,
      'is_adult': isAdult,
      'added_at': addedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
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
