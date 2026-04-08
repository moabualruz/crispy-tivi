// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plex_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlexMetadata _$PlexMetadataFromJson(Map<String, dynamic> json) => PlexMetadata(
  ratingKey: json['ratingKey'] as String?,
  key: json['key'] as String?,
  guid: json['guid'] as String?,
  type: json['type'] as String?,
  title: json['title'] as String?,
  titleSort: json['titleSort'] as String?,
  summary: json['summary'] as String?,
  index: (json['index'] as num?)?.toInt(),
  thumb: json['thumb'] as String?,
  art: json['art'] as String?,
  banner: json['banner'] as String?,
  theme: json['theme'] as String?,
  duration: (json['duration'] as num?)?.toInt(),
  originallyAvailableAt: json['originallyAvailableAt'] as String?,
  addedAt: (json['addedAt'] as num?)?.toInt(),
  updatedAt: (json['updatedAt'] as num?)?.toInt(),
  year: (json['year'] as num?)?.toInt(),
  media:
      (json['Media'] as List<dynamic>?)
          ?.map((e) => PlexMedia.fromJson(e as Map<String, dynamic>))
          .toList(),
  viewOffset: (json['viewOffset'] as num?)?.toInt(),
  viewCount: (json['viewCount'] as num?)?.toInt(),
  contentRating: json['contentRating'] as String?,
  genre:
      (json['Genre'] as List<dynamic>?)
          ?.map((e) => PlexTag.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  director:
      (json['Director'] as List<dynamic>?)
          ?.map((e) => PlexTag.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  role:
      (json['Role'] as List<dynamic>?)
          ?.map((e) => PlexTag.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  studio: json['studio'] as String?,
  audienceRating: (json['audienceRating'] as num?)?.toDouble(),
  rating: (json['rating'] as num?)?.toDouble(),
  parentIndex: (json['parentIndex'] as num?)?.toInt(),
  parentRatingKey: json['parentRatingKey'] as String?,
  grandparentRatingKey: json['grandparentRatingKey'] as String?,
  originalTitle: json['originalTitle'] as String?,
);

Map<String, dynamic> _$PlexMetadataToJson(PlexMetadata instance) =>
    <String, dynamic>{
      'ratingKey': instance.ratingKey,
      'key': instance.key,
      'guid': instance.guid,
      'type': instance.type,
      'title': instance.title,
      'titleSort': instance.titleSort,
      'summary': instance.summary,
      'index': instance.index,
      'thumb': instance.thumb,
      'art': instance.art,
      'banner': instance.banner,
      'theme': instance.theme,
      'duration': instance.duration,
      'originallyAvailableAt': instance.originallyAvailableAt,
      'addedAt': instance.addedAt,
      'updatedAt': instance.updatedAt,
      'year': instance.year,
      'Media': instance.media,
      'viewOffset': instance.viewOffset,
      'viewCount': instance.viewCount,
      'contentRating': instance.contentRating,
      'Genre': instance.genre,
      'Director': instance.director,
      'Role': instance.role,
      'studio': instance.studio,
      'audienceRating': instance.audienceRating,
      'rating': instance.rating,
      'parentIndex': instance.parentIndex,
      'parentRatingKey': instance.parentRatingKey,
      'grandparentRatingKey': instance.grandparentRatingKey,
      'originalTitle': instance.originalTitle,
    };

PlexMedia _$PlexMediaFromJson(Map<String, dynamic> json) => PlexMedia(
  id: (json['id'] as num?)?.toInt(),
  duration: (json['duration'] as num?)?.toInt(),
  bitrate: (json['bitrate'] as num?)?.toInt(),
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
  audioChannels: (json['audioChannels'] as num?)?.toInt(),
  audioCodec: json['audioCodec'] as String?,
  videoCodec: json['videoCodec'] as String?,
  videoResolution: json['videoResolution'] as String?,
  container: json['container'] as String?,
  videoFrameRate: json['videoFrameRate'] as String?,
  part:
      (json['Part'] as List<dynamic>?)
          ?.map((e) => PlexPart.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$PlexMediaToJson(PlexMedia instance) => <String, dynamic>{
  'id': instance.id,
  'duration': instance.duration,
  'bitrate': instance.bitrate,
  'width': instance.width,
  'height': instance.height,
  'aspectRatio': instance.aspectRatio,
  'audioChannels': instance.audioChannels,
  'audioCodec': instance.audioCodec,
  'videoCodec': instance.videoCodec,
  'videoResolution': instance.videoResolution,
  'container': instance.container,
  'videoFrameRate': instance.videoFrameRate,
  'Part': instance.part,
};

PlexPart _$PlexPartFromJson(Map<String, dynamic> json) => PlexPart(
  id: (json['id'] as num?)?.toInt(),
  key: json['key'] as String?,
  duration: (json['duration'] as num?)?.toInt(),
  file: json['file'] as String?,
  size: (json['size'] as num?)?.toInt(),
  container: json['container'] as String?,
  videoProfile: json['videoProfile'] as String?,
);

Map<String, dynamic> _$PlexPartToJson(PlexPart instance) => <String, dynamic>{
  'id': instance.id,
  'key': instance.key,
  'duration': instance.duration,
  'file': instance.file,
  'size': instance.size,
  'container': instance.container,
  'videoProfile': instance.videoProfile,
};

PlexTag _$PlexTagFromJson(Map<String, dynamic> json) => PlexTag(
  tag: json['tag'] as String,
  role: json['role'] as String?,
  thumb: json['thumb'] as String?,
);

Map<String, dynamic> _$PlexTagToJson(PlexTag instance) => <String, dynamic>{
  'tag': instance.tag,
  'role': instance.role,
  'thumb': instance.thumb,
};
