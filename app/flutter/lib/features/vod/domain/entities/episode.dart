import 'package:meta/meta.dart';

import 'vod_item.dart';

/// An episode within a season of a TV series.
///
/// Domain entity — pure Dart, no infrastructure dependencies.
/// Maps to the Rust `Episode` struct / `db_episodes` table.
@immutable
class Episode {
  const Episode({
    required this.id,
    required this.seasonId,
    required this.sourceId,
    required this.nativeId,
    required this.episodeNumber,
    this.name,
    this.description,
    this.posterUrl,
    this.streamUrl,
    this.containerExt,
    this.stalkerCmd,
    this.resolvedUrl,
    this.resolvedAt,
    this.durationMinutes,
    this.airDate,
    this.rating,
    this.contentRating,
    this.tmdbId,
    this.addedAt,
    this.updatedAt,
  });

  /// Creates an [Episode] from a legacy [VodItem] for gradual migration.
  ///
  /// Requires [seasonId] since [VodItem] does not carry season references.
  factory Episode.fromVodItem(VodItem item, {required String seasonId}) {
    return Episode(
      id: item.id,
      seasonId: seasonId,
      sourceId: item.sourceId ?? '',
      nativeId: item.id,
      episodeNumber: item.episodeNumber ?? 0,
      name: item.name,
      description: item.description,
      posterUrl: item.posterUrl,
      streamUrl: item.streamUrl,
      containerExt: item.extension,
      durationMinutes: item.duration,
      rating: item.rating,
      addedAt: item.addedAt,
      updatedAt: item.updatedAt,
    );
  }

  /// Unique episode identifier.
  final String id;

  /// Parent season ID.
  final String seasonId;

  /// Source this episode belongs to.
  final String sourceId;

  /// Source-native ID.
  final String nativeId;

  /// Episode number within the season.
  final int episodeNumber;

  /// Episode name/title.
  final String? name;

  /// Synopsis / plot description.
  final String? description;

  /// URL of the episode poster/thumbnail.
  final String? posterUrl;

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

  /// Duration in minutes.
  final int? durationMinutes;

  /// Air date (e.g. "2024-01-15").
  final String? airDate;

  /// Rating string.
  final String? rating;

  /// Content/parental rating.
  final String? contentRating;

  /// TMDB episode ID.
  final int? tmdbId;

  /// When the episode was first imported.
  final DateTime? addedAt;

  /// When the episode was last refreshed.
  final DateTime? updatedAt;

  /// Display label for the episode (e.g. "E1: Pilot" or "Episode 1").
  String get displayName =>
      name != null ? 'E$episodeNumber: $name' : 'Episode $episodeNumber';

  /// Converts this [Episode] back to a legacy [VodItem].
  ///
  /// Requires [seriesId] and [seasonNumber] for the VodItem fields.
  VodItem toVodItem({String? seriesId, int? seasonNumber}) {
    return VodItem(
      id: id,
      name: name ?? 'Episode $episodeNumber',
      streamUrl: streamUrl ?? '',
      type: VodType.episode,
      posterUrl: posterUrl,
      description: description,
      rating: rating,
      duration: durationMinutes,
      extension: containerExt,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      addedAt: addedAt,
      updatedAt: updatedAt,
      sourceId: sourceId,
    );
  }

  /// Creates a copy with optional field overrides.
  Episode copyWith({
    String? id,
    String? seasonId,
    String? sourceId,
    String? nativeId,
    int? episodeNumber,
    String? name,
    String? description,
    String? posterUrl,
    String? streamUrl,
    String? containerExt,
    String? stalkerCmd,
    String? resolvedUrl,
    int? resolvedAt,
    int? durationMinutes,
    String? airDate,
    String? rating,
    String? contentRating,
    int? tmdbId,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) {
    return Episode(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      sourceId: sourceId ?? this.sourceId,
      nativeId: nativeId ?? this.nativeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      name: name ?? this.name,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      containerExt: containerExt ?? this.containerExt,
      stalkerCmd: stalkerCmd ?? this.stalkerCmd,
      resolvedUrl: resolvedUrl ?? this.resolvedUrl,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      airDate: airDate ?? this.airDate,
      rating: rating ?? this.rating,
      contentRating: contentRating ?? this.contentRating,
      tmdbId: tmdbId ?? this.tmdbId,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Episode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'Episode($displayName, season=$seasonId)';
}
