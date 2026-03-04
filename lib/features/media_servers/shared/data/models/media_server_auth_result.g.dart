// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server_auth_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaServerAuthResult _$MediaServerAuthResultFromJson(
  Map<String, dynamic> json,
) => MediaServerAuthResult(
  user: MediaServerUser.fromJson(json['User'] as Map<String, dynamic>),
  accessToken: json['AccessToken'] as String,
  serverId: json['ServerId'] as String?,
);

Map<String, dynamic> _$MediaServerAuthResultToJson(
  MediaServerAuthResult instance,
) => <String, dynamic>{
  'User': instance.user,
  'AccessToken': instance.accessToken,
  'ServerId': instance.serverId,
};
