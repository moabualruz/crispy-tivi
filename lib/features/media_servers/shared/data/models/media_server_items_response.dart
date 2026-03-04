import 'package:json_annotation/json_annotation.dart';

import 'media_server_item.dart';

part 'media_server_items_response.g.dart';

@JsonSerializable()
class MediaServerItemsResponse {
  const MediaServerItemsResponse({
    this.items = const [],
    this.totalRecordCount = 0,
  });

  @JsonKey(name: 'Items')
  final List<MediaServerItem> items;

  @JsonKey(name: 'TotalRecordCount')
  final int totalRecordCount;

  factory MediaServerItemsResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaServerItemsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MediaServerItemsResponseToJson(this);
}
