// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plex_directory.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlexDirectory _$PlexDirectoryFromJson(Map<String, dynamic> json) =>
    PlexDirectory(
      key: json['key'] as String?,
      type: json['type'] as String?,
      title: json['title'] as String?,
      agent: json['agent'] as String?,
      scanner: json['scanner'] as String?,
      language: json['language'] as String?,
      uuid: json['uuid'] as String?,
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      scannedAt: (json['scannedAt'] as num?)?.toInt(),
      content: json['content'] as bool?,
      directory: json['directory'] as bool?,
      contentChangedAt: (json['contentChangedAt'] as num?)?.toInt(),
      hidden: (json['hidden'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlexDirectoryToJson(PlexDirectory instance) =>
    <String, dynamic>{
      'key': instance.key,
      'type': instance.type,
      'title': instance.title,
      'agent': instance.agent,
      'scanner': instance.scanner,
      'language': instance.language,
      'uuid': instance.uuid,
      'updatedAt': instance.updatedAt,
      'createdAt': instance.createdAt,
      'scannedAt': instance.scannedAt,
      'content': instance.content,
      'directory': instance.directory,
      'contentChangedAt': instance.contentChangedAt,
      'hidden': instance.hidden,
    };
