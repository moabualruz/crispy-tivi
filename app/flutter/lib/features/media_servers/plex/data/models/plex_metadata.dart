import 'package:json_annotation/json_annotation.dart';

import '../../../../../core/domain/mixins/playback_progress_mixin.dart';

part 'plex_metadata.g.dart';

@JsonSerializable()
class PlexMetadata with PlaybackProgressMixin {
  const PlexMetadata({
    this.ratingKey,
    this.key,
    this.guid,
    this.type,
    this.title,
    this.titleSort,
    this.summary,
    this.index,
    this.thumb,
    this.art,
    this.banner,
    this.theme,
    this.duration,
    this.originallyAvailableAt,
    this.addedAt,
    this.updatedAt,
    this.year,
    this.media,
    this.viewOffset,
    this.viewCount,
    this.contentRating,
    this.genre = const [],
    this.director = const [],
    this.role = const [],
    this.studio,
    this.audienceRating,
    this.rating,
    this.parentIndex,
    this.parentRatingKey,
    this.grandparentRatingKey,
    this.originalTitle,
  });

  factory PlexMetadata.fromJson(Map<String, dynamic> json) =>
      _$PlexMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$PlexMetadataToJson(this);

  final String? ratingKey;
  final String? key;
  final String? guid;
  final String? type;
  final String? title;
  final String? titleSort;
  final String? summary;
  final int? index;
  final String? thumb;
  final String? art;
  final String? banner;
  final String? theme;
  final int? duration;
  final String? originallyAvailableAt;
  final int? addedAt;
  final int? updatedAt;
  final int? year;

  @JsonKey(name: 'Media')
  final List<PlexMedia>? media;

  /// Current playback position in milliseconds (for resume).
  final int? viewOffset;

  /// Number of times item has been watched (>0 means watched).
  final int? viewCount;

  /// Content rating (e.g., "PG-13", "R").
  final String? contentRating;

  /// Genre tags (e.g. [{"tag": "Action"}, {"tag": "Drama"}]).
  @JsonKey(name: 'Genre')
  final List<PlexTag> genre;

  /// Director tags (e.g. [{"tag": "Christopher Nolan"}]).
  @JsonKey(name: 'Director')
  final List<PlexTag> director;

  /// Cast/role tags (e.g. [{"tag": "Tom Hanks", "role": "Forrest"}]).
  @JsonKey(name: 'Role')
  final List<PlexTag> role;

  /// Studio name (e.g. "Warner Bros.").
  final String? studio;

  /// Audience rating (e.g. 8.5 from Rotten Tomatoes audience score).
  final double? audienceRating;

  /// Critic rating (e.g. 9.0 from Rotten Tomatoes or IMDb).
  @JsonKey(name: 'rating')
  final double? rating;

  /// Parent season index (1-based, for episodes).
  final int? parentIndex;

  /// Parent rating key (series ID for episodes, show ID for seasons).
  final String? parentRatingKey;

  /// Grandparent rating key (show ID for episodes).
  final String? grandparentRatingKey;

  /// Original title (e.g. foreign language original name).
  final String? originalTitle;

  /// Extract genre names as a flat list.
  List<String> get genreNames => genre.map((g) => g.tag).toList();

  /// Extract director names as a flat list.
  List<String> get directorNames => director.map((d) => d.tag).toList();

  /// First director name (convenience getter).
  String? get directorName {
    final dirs = directorNames;
    return dirs.isNotEmpty ? dirs.join(', ') : null;
  }

  /// Extract cast member names as a flat list.
  List<String> get castNames => role.map((r) => r.tag).toList();

  /// Whether the item has been completely watched.
  @override
  bool get isWatched => viewCount != null && viewCount! > 0;

  /// Playback position in milliseconds.
  @override
  int? get playbackPositionMs => viewOffset;
}

@JsonSerializable()
class PlexMedia {
  const PlexMedia({
    this.id,
    this.duration,
    this.bitrate,
    this.width,
    this.height,
    this.aspectRatio,
    this.audioChannels,
    this.audioCodec,
    this.videoCodec,
    this.videoResolution,
    this.container,
    this.videoFrameRate,
    this.part,
  });

  factory PlexMedia.fromJson(Map<String, dynamic> json) =>
      _$PlexMediaFromJson(json);

  Map<String, dynamic> toJson() => _$PlexMediaToJson(this);

  final int? id;
  final int? duration;
  final int? bitrate;
  final int? width;
  final int? height;
  final double? aspectRatio;
  final int? audioChannels;
  final String? audioCodec;
  final String? videoCodec;
  final String? videoResolution;
  final String? container;
  final String? videoFrameRate;

  @JsonKey(name: 'Part')
  final List<PlexPart>? part;
}

@JsonSerializable()
class PlexPart {
  const PlexPart({
    this.id,
    this.key,
    this.duration,
    this.file,
    this.size,
    this.container,
    this.videoProfile,
  });

  factory PlexPart.fromJson(Map<String, dynamic> json) =>
      _$PlexPartFromJson(json);

  Map<String, dynamic> toJson() => _$PlexPartToJson(this);

  final int? id;
  final String? key;
  final int? duration;
  final String? file;
  final int? size;
  final String? container;
  final String? videoProfile;
}

/// A generic tag object used by Plex for Genre, Director, Role, etc.
///
/// Plex returns these as `[{"tag": "Action"}, {"tag": "Drama"}]` for genres,
/// `[{"tag": "Christopher Nolan"}]` for directors, and
/// `[{"tag": "Tom Hanks", "role": "Forrest Gump"}]` for cast roles.
@JsonSerializable()
class PlexTag {
  const PlexTag({required this.tag, this.role, this.thumb});

  /// The display name (genre name, person name, etc.).
  final String tag;

  /// Character name for cast members (only present on Role tags).
  final String? role;

  /// Thumbnail URL for person photos (only present on Role tags).
  final String? thumb;

  factory PlexTag.fromJson(Map<String, dynamic> json) =>
      _$PlexTagFromJson(json);

  Map<String, dynamic> toJson() => _$PlexTagToJson(this);
}
