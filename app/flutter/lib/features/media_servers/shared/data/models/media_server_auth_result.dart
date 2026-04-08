import 'package:json_annotation/json_annotation.dart';

import 'media_server_user.dart';

part 'media_server_auth_result.g.dart';

@JsonSerializable()
class MediaServerAuthResult {
  const MediaServerAuthResult({
    required this.user,
    required this.accessToken,
    this.serverId,
  });

  @JsonKey(name: 'User')
  final MediaServerUser user;

  @JsonKey(name: 'AccessToken')
  final String accessToken;

  @JsonKey(name: 'ServerId')
  final String? serverId;

  factory MediaServerAuthResult.fromJson(Map<String, dynamic> json) =>
      _$MediaServerAuthResultFromJson(json);

  Map<String, dynamic> toJson() => _$MediaServerAuthResultToJson(this);
}
