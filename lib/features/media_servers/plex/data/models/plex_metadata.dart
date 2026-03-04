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
