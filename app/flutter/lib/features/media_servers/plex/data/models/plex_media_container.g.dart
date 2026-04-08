// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plex_media_container.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlexMediaContainer _$PlexMediaContainerFromJson(Map<String, dynamic> json) =>
    PlexMediaContainer(
      size: (json['size'] as num?)?.toInt(),
      totalSize: (json['totalSize'] as num?)?.toInt(),
      offset: (json['offset'] as num?)?.toInt(),
      allowSync: json['allowSync'] as bool?,
      identifier: json['identifier'] as String?,
      mediaTagPrefix: json['mediaTagPrefix'] as String?,
      mediaTagVersion: json['mediaTagVersion'] as String?,
      title1: json['title1'] as String?,
      title2: json['title2'] as String?,
      viewGroup: json['viewGroup'] as String?,
      viewMode: (json['viewMode'] as num?)?.toInt(),
      directory:
          (json['Directory'] as List<dynamic>?)
              ?.map((e) => PlexDirectory.fromJson(e as Map<String, dynamic>))
              .toList(),
      metadata:
          (json['Metadata'] as List<dynamic>?)
              ?.map((e) => PlexMetadata.fromJson(e as Map<String, dynamic>))
              .toList(),
      machineIdentifier: json['MachineIdentifier'] as String?,
      friendlyName: json['friendlyName'] as String?,
    );

Map<String, dynamic> _$PlexMediaContainerToJson(PlexMediaContainer instance) =>
    <String, dynamic>{
      'size': instance.size,
      'totalSize': instance.totalSize,
      'offset': instance.offset,
      'allowSync': instance.allowSync,
      'identifier': instance.identifier,
      'mediaTagPrefix': instance.mediaTagPrefix,
      'mediaTagVersion': instance.mediaTagVersion,
      'title1': instance.title1,
      'title2': instance.title2,
      'viewGroup': instance.viewGroup,
      'viewMode': instance.viewMode,
      'MachineIdentifier': instance.machineIdentifier,
      'friendlyName': instance.friendlyName,
      'Directory': instance.directory,
      'Metadata': instance.metadata,
    };
