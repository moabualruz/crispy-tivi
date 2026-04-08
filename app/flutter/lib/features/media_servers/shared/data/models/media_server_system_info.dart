import 'package:json_annotation/json_annotation.dart';

part 'media_server_system_info.g.dart';

@JsonSerializable()
class MediaServerSystemInfo {
  const MediaServerSystemInfo({
    required this.serverName,
    required this.version,
    required this.id,
  });

  @JsonKey(name: 'ServerName')
  final String serverName;

  @JsonKey(name: 'Version')
  final String version;

  @JsonKey(name: 'Id')
  final String id;

  factory MediaServerSystemInfo.fromJson(Map<String, dynamic> json) =>
      _$MediaServerSystemInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MediaServerSystemInfoToJson(this);
}
