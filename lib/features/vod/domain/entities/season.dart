import 'package:flutter/foundation.dart';

/// A season within a TV series.
///
/// Domain entity — pure Dart, no infrastructure dependencies.
/// Maps to the Rust `Season` struct / `db_seasons` table.
@immutable
class Season {
  const Season({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    this.name,
    this.posterUrl,
    this.episodeCount,
    this.airDate,
  });

  /// Creates a [Season] from a JSON map (for future FFI integration).
  factory Season.fromJson(Map<String, dynamic> json) {
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

  /// Unique season identifier.
  final String id;

  /// Parent series ID.
  final String seriesId;

  /// Season number.
  final int seasonNumber;

  /// Season name/title.
  final String? name;

  /// URL of the season poster image.
  final String? posterUrl;

  /// Number of episodes in this season.
  final int? episodeCount;

  /// Air date (e.g. "2024-01-15").
  final String? airDate;

  /// Display label for the season (e.g. "Season 1" or custom name).
  String get displayName => name ?? 'Season $seasonNumber';

  /// Serializes this [Season] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'series_id': seriesId,
      'season_number': seasonNumber,
      'name': name,
      'poster_url': posterUrl,
      'episode_count': episodeCount,
      'air_date': airDate,
    };
  }

  /// Creates a copy with optional field overrides.
  Season copyWith({
    String? id,
    String? seriesId,
    int? seasonNumber,
    String? name,
    String? posterUrl,
    int? episodeCount,
    String? airDate,
  }) {
    return Season(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      name: name ?? this.name,
      posterUrl: posterUrl ?? this.posterUrl,
      episodeCount: episodeCount ?? this.episodeCount,
      airDate: airDate ?? this.airDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Season && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'Season($displayName, series=$seriesId)';
}
