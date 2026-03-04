import 'package:flutter/foundation.dart';

/// A VOD (Video On Demand) item — movie or series episode.
///
/// Domain entity — pure Dart, no infrastructure dependencies.
@immutable
class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.type,
    this.posterUrl,
    this.backdropUrl,
    this.description,
    this.rating,
    this.year,
    this.duration,
    this.category,
    this.cast,
    this.director,
    this.seriesId,
    this.seasonCount,
    this.seasonNumber,
    this.episodeNumber,
    this.extension,
    this.isFavorite = false,
    this.addedAt,
    this.updatedAt,
    this.sourceId,
  });

  /// Unique identifier.
  final String id;

  /// Display name / title.
  final String name;

  /// Direct stream URL for playback.
  final String streamUrl;

  /// Whether this is a movie or series episode.
  final VodType type;

  /// Poster / thumbnail image URL.
  final String? posterUrl;

  /// Backdrop / hero banner URL.
  final String? backdropUrl;

  /// Synopsis / description.
  final String? description;

  /// Rating (e.g., "7.5", "PG-13").
  final String? rating;

  /// Release year.
  final int? year;

  /// Duration in minutes (for movies).
  final int? duration;

  /// Category / genre name.
  final String? category;

  /// Cast members — list of actor/crew names (e.g. ["Tom Hanks",
  /// "Robin Wright"]). Populated from Xtream/M3U metadata when
  /// available. Null when no cast data is provided by the source.
  final List<String>? cast;

  /// Director of the movie or series.
  final String? director;

  /// Parent series ID (for episodes).
  final String? seriesId;

  /// Total number of seasons (for series).
  final int? seasonCount;

  /// Season number (for episodes).
  final int? seasonNumber;

  /// Episode number (for episodes).
  final int? episodeNumber;

  /// File extension (mp4, mkv, etc.).
  final String? extension;

  /// Whether this item is favorited by the user.
  final bool isFavorite;

  /// Timestamp when this item was first added (delta sync tracking).
  final DateTime? addedAt;

  /// Timestamp when this item was last updated (delta sync tracking).
  final DateTime? updatedAt;

  /// Which playlist source this item belongs to.
  final String? sourceId;

  /// Creates a copy with optional field overrides.
  VodItem copyWith({
    String? id,
    String? name,
    String? streamUrl,
    VodType? type,
    String? posterUrl,
    String? backdropUrl,
    String? description,
    String? rating,
    int? year,
    int? duration,
    String? category,
    List<String>? cast,
    String? director,
    String? seriesId,
    int? seasonCount,
    int? seasonNumber,
    int? episodeNumber,
    String? extension,
    bool? isFavorite,
    DateTime? addedAt,
    DateTime? updatedAt,
    String? sourceId,
  }) {
    return VodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      type: type ?? this.type,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      seriesId: seriesId ?? this.seriesId,
      seasonCount: seasonCount ?? this.seasonCount,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      extension: extension ?? this.extension,
      isFavorite: isFavorite ?? this.isFavorite,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VodItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'VodItem($name, type=$type, source=$sourceId)';
}

/// VOD content type.
enum VodType { movie, series, episode }

/// Converts between [VodType] and the string `mediaType`
/// used in watch history and playback session records.
extension VodTypeConversion on VodType {
  /// Creates a [VodType] from a `mediaType` string.
  ///
  /// `'series'` → [VodType.series]; all other values → [VodType.movie].
  static VodType fromMediaType(String mediaType) =>
      mediaType == 'series' ? VodType.series : VodType.movie;

  /// Converts this [VodType] to its `mediaType` string representation.
  ///
  /// [VodType.movie] → `'movie'`; others → `'episode'`.
  String get mediaType => this == VodType.movie ? 'movie' : 'episode';
}
