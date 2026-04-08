import 'package:json_annotation/json_annotation.dart';
import 'plex_directory.dart';
import 'plex_metadata.dart';

part 'plex_media_container.g.dart';

@JsonSerializable()
class PlexMediaContainer {
  const PlexMediaContainer({
    this.size,
    this.totalSize,
    this.offset,
    this.allowSync,
    this.identifier,
    this.mediaTagPrefix,
    this.mediaTagVersion,
    this.title1,
    this.title2,
    this.viewGroup,
    this.viewMode,
    this.directory,
    this.metadata,
    this.machineIdentifier,
    this.friendlyName,
  });

  factory PlexMediaContainer.fromJson(Map<String, dynamic> json) =>
      _$PlexMediaContainerFromJson(json);

  Map<String, dynamic> toJson() => _$PlexMediaContainerToJson(this);

  /// Number of items in this response.
  final int? size;

  /// Total number of items available (for pagination).
  final int? totalSize;

  /// Starting index of this response (for pagination).
  final int? offset;

  final bool? allowSync;
  final String? identifier;
  final String? mediaTagPrefix;
  final String? mediaTagVersion;
  final String? title1;
  final String? title2;
  final String? viewGroup;
  final int? viewMode;

  // Plex returns "MachineIdentifier" in identity check
  @JsonKey(name: 'MachineIdentifier')
  final String? machineIdentifier;

  final String? friendlyName;

  @JsonKey(name: 'Directory')
  final List<PlexDirectory>? directory;

  @JsonKey(name: 'Metadata')
  final List<PlexMetadata>? metadata;
}
