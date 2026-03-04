// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server_user_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaServerUserData _$MediaServerUserDataFromJson(Map<String, dynamic> json) =>
    MediaServerUserData(
      playbackPositionTicks: (json['PlaybackPositionTicks'] as num?)?.toInt(),
      playCount: (json['PlayCount'] as num?)?.toInt(),
      isFavorite: json['IsFavorite'] as bool? ?? false,
      played: json['Played'] as bool? ?? false,
      key: json['Key'] as String?,
    );

Map<String, dynamic> _$MediaServerUserDataToJson(
  MediaServerUserData instance,
) => <String, dynamic>{
  'PlaybackPositionTicks': instance.playbackPositionTicks,
  'PlayCount': instance.playCount,
  'IsFavorite': instance.isFavorite,
  'Played': instance.played,
  'Key': instance.key,
};
