import 'package:json_annotation/json_annotation.dart';

part 'plex_directory.g.dart';

@JsonSerializable()
class PlexDirectory {
  const PlexDirectory({
    this.key,
    this.type,
    this.title,
    this.agent,
    this.scanner,
    this.language,
    this.uuid,
    this.updatedAt,
    this.createdAt,
    this.scannedAt,
    this.content,
    this.directory,
    this.contentChangedAt,
    this.hidden,
  });

  factory PlexDirectory.fromJson(Map<String, dynamic> json) =>
      _$PlexDirectoryFromJson(json);

  Map<String, dynamic> toJson() => _$PlexDirectoryToJson(this);

  final String? key;
  final String? type;
  final String? title;
  final String? agent;
  final String? scanner;
  final String? language;
  final String? uuid;
  final int? updatedAt;
  final int? createdAt;
  final int? scannedAt;
  final bool? content;
  final bool? directory;
  final int? contentChangedAt;
  final int? hidden;
}
