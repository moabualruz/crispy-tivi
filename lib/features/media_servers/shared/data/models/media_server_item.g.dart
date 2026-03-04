// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaServerItem _$MediaServerItemFromJson(Map<String, dynamic> json) =>
    MediaServerItem(
      id: json['Id'] as String,
      name: json['Name'] as String,
      originalTitle: json['OriginalTitle'] as String?,
      serverId: json['ServerId'] as String?,
      type: json['Type'] as String?,
      parentId: json['ParentId'] as String?,
      imageTags:
          (json['ImageTags'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      overview: json['Overview'] as String?,
      runTimeTicks: (json['RunTimeTicks'] as num?)?.toInt(),
      productionYear: (json['ProductionYear'] as num?)?.toInt(),
      premiereDate:
          json['PremiereDate'] == null
              ? null
              : DateTime.parse(json['PremiereDate'] as String),
      officialRating: json['OfficialRating'] as String?,
      isFolder: json['IsFolder'] as bool? ?? false,
      collectionType: json['CollectionType'] as String?,
      userData:
          json['UserData'] == null
              ? null
              : MediaServerUserData.fromJson(
                json['UserData'] as Map<String, dynamic>,
              ),
      backdropImageTags:
          (json['BackdropImageTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      indexNumber: (json['IndexNumber'] as num?)?.toInt(),
      parentIndexNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
      width: (json['Width'] as num?)?.toInt(),
      height: (json['Height'] as num?)?.toInt(),
      videoRange: json['VideoRange'] as String?,
    );

Map<String, dynamic> _$MediaServerItemToJson(MediaServerItem instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Name': instance.name,
      'OriginalTitle': instance.originalTitle,
      'ServerId': instance.serverId,
      'Type': instance.type,
      'ParentId': instance.parentId,
      'ImageTags': instance.imageTags,
      'Overview': instance.overview,
      'RunTimeTicks': instance.runTimeTicks,
      'ProductionYear': instance.productionYear,
      'PremiereDate': instance.premiereDate?.toIso8601String(),
      'OfficialRating': instance.officialRating,
      'IsFolder': instance.isFolder,
      'CollectionType': instance.collectionType,
      'UserData': instance.userData,
      'BackdropImageTags': instance.backdropImageTags,
      'IndexNumber': instance.indexNumber,
      'ParentIndexNumber': instance.parentIndexNumber,
      'Width': instance.width,
      'Height': instance.height,
      'VideoRange': instance.videoRange,
    };
