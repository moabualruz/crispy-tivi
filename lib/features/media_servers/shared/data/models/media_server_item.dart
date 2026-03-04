import 'package:json_annotation/json_annotation.dart';

import '../../../../../core/domain/mixins/playback_progress_mixin.dart';
import 'media_server_user_data.dart';

part 'media_server_item.g.dart';

@JsonSerializable()
class MediaServerItem with PlaybackProgressMixin {
  const MediaServerItem({
    required this.id,
    required this.name,
    this.originalTitle,
    this.serverId,
    this.type,
    this.parentId,
    this.imageTags = const {},
    this.overview,
    this.runTimeTicks,
    this.productionYear,
    this.premiereDate,
    this.officialRating,
    this.isFolder = false,
    this.collectionType,
    this.userData,
    this.backdropImageTags,
    this.indexNumber,
    this.parentIndexNumber,
    this.width,
    this.height,
    this.videoRange,
  });

  @JsonKey(name: 'Id')
  final String id;

  @JsonKey(name: 'Name')
  final String name;

  @JsonKey(name: 'OriginalTitle')
  final String? originalTitle;

  @JsonKey(name: 'ServerId')
  final String? serverId;

  /// Type: "Movie", "Series", "Episode", "BoxSet", "Folder", "CollectionFolder"
  @JsonKey(name: 'Type')
  final String? type;

  @JsonKey(name: 'ParentId')
  final String? parentId;

  /// Map of ImageType -> Tag
  @JsonKey(name: 'ImageTags')
  final Map<String, String> imageTags;

  @JsonKey(name: 'Overview')
  final String? overview;

  @JsonKey(name: 'RunTimeTicks')
  final int? runTimeTicks;

  @JsonKey(name: 'ProductionYear')
  final int? productionYear;

  @JsonKey(name: 'PremiereDate')
  final DateTime? premiereDate;

  @JsonKey(name: 'OfficialRating')
  final String? officialRating;

  @JsonKey(name: 'IsFolder')
  final bool isFolder;

  /// E.g. "movies", "tvshows" for root folders
  @JsonKey(name: 'CollectionType')
  final String? collectionType;

  /// User-specific data (watched status, playback position, favorites).
  @JsonKey(name: 'UserData')
  final MediaServerUserData? userData;

  /// Backdrop image tags for this item.
  @JsonKey(name: 'BackdropImageTags')
  final List<String>? backdropImageTags;

  /// Episode index within its season (1-based).
  ///
  /// Only present for [type] == `'Episode'`. Used to build the
  /// S01E03-style badge in series screens.
  @JsonKey(name: 'IndexNumber')
  final int? indexNumber;

  /// Parent season index (1-based) for episode items.
  ///
  /// Maps to `ParentIndexNumber` in the Emby/Jellyfin JSON response.
  @JsonKey(name: 'ParentIndexNumber')
  final int? parentIndexNumber;

  /// Video width in pixels (e.g. 3840 for 4K).
  ///
  /// Present on movie/episode items — null for folders/series.
  @JsonKey(name: 'Width')
  final int? width;

  /// Video height in pixels (e.g. 2160 for 4K).
  @JsonKey(name: 'Height')
  final int? height;

  /// Video range type as returned by the server (e.g. "HDR10",
  /// "SDR", "DOVI", "HLG").
  @JsonKey(name: 'VideoRange')
  final String? videoRange;

  factory MediaServerItem.fromJson(Map<String, dynamic> json) =>
      _$MediaServerItemFromJson(json);

  Map<String, dynamic> toJson() => _$MediaServerItemToJson(this);

  /// Helper: calculate duration in milliseconds (1 tick = 100ns = 0.0001ms)
  /// 10000 ticks = 1ms.
  int? get durationMs =>
      runTimeTicks != null ? (runTimeTicks! / 10000).round() : null;

  String? get primaryImageTag => imageTags['Primary'];

  /// First backdrop image tag (if available).
  String? get backdropImageTag =>
      backdropImageTags != null && backdropImageTags!.isNotEmpty
          ? backdropImageTags!.first
          : null;

  /// Whether the item has been completely watched.
  @override
  bool get isWatched => userData?.played ?? false;

  /// Playback position in milliseconds (for resume).
  @override
  int? get playbackPositionMs => userData?.playbackPositionMs;
}
