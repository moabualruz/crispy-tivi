import 'package:json_annotation/json_annotation.dart';

part 'media_server_user_data.g.dart';

/// User-specific data for an Emby/Jellyfin item (watched status, progress).
@JsonSerializable()
class MediaServerUserData {
  const MediaServerUserData({
    this.playbackPositionTicks,
    this.playCount,
    this.isFavorite = false,
    this.played = false,
    this.key,
  });

  /// Current playback position in ticks (100ns units).
  @JsonKey(name: 'PlaybackPositionTicks')
  final int? playbackPositionTicks;

  /// Number of times the item has been played.
  @JsonKey(name: 'PlayCount')
  final int? playCount;

  /// Whether the item is marked as a favorite.
  @JsonKey(name: 'IsFavorite')
  final bool isFavorite;

  /// Whether the item has been completely watched.
  @JsonKey(name: 'Played')
  final bool played;

  /// Unique key for the user data entry.
  @JsonKey(name: 'Key')
  final String? key;

  factory MediaServerUserData.fromJson(Map<String, dynamic> json) =>
      _$MediaServerUserDataFromJson(json);

  Map<String, dynamic> toJson() => _$MediaServerUserDataToJson(this);

  /// Convert playback position to milliseconds.
  int? get playbackPositionMs =>
      playbackPositionTicks != null
          ? (playbackPositionTicks! / 10000).round()
          : null;
}
