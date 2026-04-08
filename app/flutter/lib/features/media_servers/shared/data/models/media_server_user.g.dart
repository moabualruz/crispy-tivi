// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaServerUser _$MediaServerUserFromJson(Map<String, dynamic> json) =>
    MediaServerUser(
      id: json['Id'] as String,
      name: json['Name'] as String,
      serverId: json['ServerId'] as String?,
      serverName: json['ServerName'] as String?,
      primaryImageTag: json['PrimaryImageTag'] as String?,
      hasPassword: json['HasPassword'] as bool? ?? false,
      hasConfiguredPassword: json['HasConfiguredPassword'] as bool? ?? false,
    );

Map<String, dynamic> _$MediaServerUserToJson(MediaServerUser instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Name': instance.name,
      'ServerId': instance.serverId,
      'ServerName': instance.serverName,
      'PrimaryImageTag': instance.primaryImageTag,
      'HasPassword': instance.hasPassword,
      'HasConfiguredPassword': instance.hasConfiguredPassword,
    };
