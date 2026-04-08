// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server_items_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaServerItemsResponse _$MediaServerItemsResponseFromJson(
  Map<String, dynamic> json,
) => MediaServerItemsResponse(
  items:
      (json['Items'] as List<dynamic>?)
          ?.map((e) => MediaServerItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  totalRecordCount: (json['TotalRecordCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MediaServerItemsResponseToJson(
  MediaServerItemsResponse instance,
) => <String, dynamic>{
  'Items': instance.items,
  'TotalRecordCount': instance.totalRecordCount,
};
