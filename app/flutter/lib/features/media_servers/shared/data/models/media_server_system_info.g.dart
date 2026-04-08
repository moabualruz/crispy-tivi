// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server_system_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaServerSystemInfo _$MediaServerSystemInfoFromJson(
  Map<String, dynamic> json,
) => MediaServerSystemInfo(
  serverName: json['ServerName'] as String,
  version: json['Version'] as String,
  id: json['Id'] as String,
);

Map<String, dynamic> _$MediaServerSystemInfoToJson(
  MediaServerSystemInfo instance,
) => <String, dynamic>{
  'ServerName': instance.serverName,
  'Version': instance.version,
  'Id': instance.id,
};
