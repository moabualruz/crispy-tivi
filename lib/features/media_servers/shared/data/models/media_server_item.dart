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
    this.genres = const [],
    this.studios = const [],
    this.people = const [],
    this.seriesId,
    this.seasonCount,
    this.container,
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

  /// Genre names for this item (e.g. ["Action", "Drama"]).
  ///
  /// Populated when the `Fields` query param includes `Genres`.
  @JsonKey(name: 'Genres')
  final List<String> genres;

  /// Studio names for this item (e.g. ["Marvel Studios"]).
  ///
  /// Populated when the `Fields` query param includes `Studios`.
  @JsonKey(name: 'Studios')
  final List<String> studios;

  /// People (cast, directors, writers) associated with this item.
  ///
  /// Populated when the `Fields` query param includes `People`.
  /// Each entry is a JSON object with `Name`, `Role`, `Type`, etc.
  @JsonKey(name: 'People')
  final List<MediaServerPerson> people;

  /// Parent series ID for episodes/seasons.
  @JsonKey(name: 'SeriesId')
  final String? seriesId;

  /// Total number of seasons (for series items).
  @JsonKey(name: 'ChildCount')
  final int? seasonCount;

  /// Container format (e.g. "mkv", "mp4") from the primary media stream.
  @JsonKey(name: 'Container')
  final String? container;

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

  /// Extract cast member names (people with Type == "Actor").
  List<String> get castNames =>
      people.where((p) => p.type == 'Actor').map((p) => p.name).toList();

  /// Extract director names (people with Type == "Director").
  List<String> get directorNames =>
      people.where((p) => p.type == 'Director').map((p) => p.name).toList();

  /// First director name (convenience getter).
  String? get directorName {
    final directors = directorNames;
    return directors.isNotEmpty ? directors.join(', ') : null;
  }
}

/// A person (actor, director, writer) associated with a media server item.
@JsonSerializable()
class MediaServerPerson {
  const MediaServerPerson({
    required this.name,
    this.id,
    this.role,
    this.type,
    this.primaryImageTag,
  });

  /// Person display name.
  @JsonKey(name: 'Name')
  final String name;

  /// Person ID on the server.
  @JsonKey(name: 'Id')
  final String? id;

  /// Role name for actors (e.g. "Tony Stark").
  @JsonKey(name: 'Role')
  final String? role;

  /// Person type: "Actor", "Director", "Writer", "Producer", etc.
  @JsonKey(name: 'Type')
  final String? type;

  /// Primary image tag for the person's photo.
  @JsonKey(name: 'PrimaryImageTag')
  final String? primaryImageTag;

  factory MediaServerPerson.fromJson(Map<String, dynamic> json) =>
      _$MediaServerPersonFromJson(json);

  Map<String, dynamic> toJson() => _$MediaServerPersonToJson(this);
}
