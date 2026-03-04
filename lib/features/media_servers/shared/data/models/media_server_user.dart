import 'package:json_annotation/json_annotation.dart';

part 'media_server_user.g.dart';

@JsonSerializable()
class MediaServerUser {
  const MediaServerUser({
    required this.id,
    required this.name,
    this.serverId,
    this.serverName,
    this.primaryImageTag,
    this.hasPassword = false,
    this.hasConfiguredPassword = false,
  });

  @JsonKey(name: 'Id')
  final String id;

  @JsonKey(name: 'Name')
  final String name;

  @JsonKey(name: 'ServerId')
  final String? serverId;

  @JsonKey(name: 'ServerName')
  final String? serverName;

  @JsonKey(name: 'PrimaryImageTag')
  final String? primaryImageTag;

  @JsonKey(name: 'HasPassword')
  final bool hasPassword;

  @JsonKey(name: 'HasConfiguredPassword')
  final bool hasConfiguredPassword;

  factory MediaServerUser.fromJson(Map<String, dynamic> json) =>
      _$MediaServerUserFromJson(json);

  Map<String, dynamic> toJson() => _$MediaServerUserToJson(this);
}
