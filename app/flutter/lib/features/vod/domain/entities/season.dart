import 'package:meta/meta.dart';

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
