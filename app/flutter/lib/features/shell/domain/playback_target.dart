import 'package:flutter/foundation.dart';

@immutable
final class PlaybackVariantOptionSnapshot {
  const PlaybackVariantOptionSnapshot({
    required this.id,
    required this.label,
    required this.uri,
    required this.transport,
    required this.live,
    required this.seekable,
    required this.resumePositionSeconds,
  });

  factory PlaybackVariantOptionSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String parent,
  }) {
    return PlaybackVariantOptionSnapshot(
      id: _readString(json, 'id', parent: parent),
      label: _readString(json, 'label', parent: parent),
      uri: _readString(json, 'uri', parent: parent),
      transport: _readString(json, 'transport', parent: parent),
      live: _readBool(json, 'live', parent: parent),
      seekable: _readBool(json, 'seekable', parent: parent),
      resumePositionSeconds: _readInt(
        json,
        'resume_position_seconds',
        parent: parent,
      ),
    );
  }

  final String id;
  final String label;
  final String uri;
  final String transport;
  final bool live;
  final bool seekable;
  final int resumePositionSeconds;
}

@immutable
final class PlaybackTrackOptionSnapshot {
  const PlaybackTrackOptionSnapshot({
    required this.id,
    required this.label,
    required this.uri,
    this.language,
  });

  factory PlaybackTrackOptionSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String parent,
  }) {
    return PlaybackTrackOptionSnapshot(
      id: _readString(json, 'id', parent: parent),
      label: _readString(json, 'label', parent: parent),
      uri: _readOptionalString(json, 'uri', parent: parent),
      language: _readNullableString(json, 'language'),
    );
  }

  final String id;
  final String label;
  final String uri;
  final String? language;
}

@immutable
final class PlaybackSourceSnapshot {
  const PlaybackSourceSnapshot({
    required this.kind,
    required this.sourceKey,
    required this.contentKey,
    required this.sourceLabel,
    required this.handoffLabel,
  });

  factory PlaybackSourceSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String parent,
  }) {
    return PlaybackSourceSnapshot(
      kind: _readString(json, 'kind', parent: parent),
      sourceKey: _readString(json, 'source_key', parent: parent),
      contentKey: _readString(json, 'content_key', parent: parent),
      sourceLabel: _readString(json, 'source_label', parent: parent),
      handoffLabel: _readString(json, 'handoff_label', parent: parent),
    );
  }

  final String kind;
  final String sourceKey;
  final String contentKey;
  final String sourceLabel;
  final String handoffLabel;
}

@immutable
final class PlaybackStreamSnapshot {
  const PlaybackStreamSnapshot({
    required this.uri,
    required this.transport,
    required this.live,
    required this.seekable,
    required this.resumePositionSeconds,
    required this.sourceOptions,
    required this.qualityOptions,
    required this.audioOptions,
    required this.subtitleOptions,
  });

  factory PlaybackStreamSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String parent,
  }) {
    return PlaybackStreamSnapshot(
      uri: _readString(json, 'uri', parent: parent),
      transport: _readString(json, 'transport', parent: parent),
      live: _readBool(json, 'live', parent: parent),
      seekable: _readBool(json, 'seekable', parent: parent),
      resumePositionSeconds: _readInt(
        json,
        'resume_position_seconds',
        parent: parent,
      ),
      sourceOptions: _readVariantOptions(
        json,
        'source_options',
        parent: parent,
      ),
      qualityOptions: _readVariantOptions(
        json,
        'quality_options',
        parent: parent,
      ),
      audioOptions: _readTrackOptions(json, 'audio_options', parent: parent),
      subtitleOptions: _readTrackOptions(
        json,
        'subtitle_options',
        parent: parent,
      ),
    );
  }

  final String uri;
  final String transport;
  final bool live;
  final bool seekable;
  final int resumePositionSeconds;
  final List<PlaybackVariantOptionSnapshot> sourceOptions;
  final List<PlaybackVariantOptionSnapshot> qualityOptions;
  final List<PlaybackTrackOptionSnapshot> audioOptions;
  final List<PlaybackTrackOptionSnapshot> subtitleOptions;
}

PlaybackSourceSnapshot? readOptionalPlaybackSource(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$parent.$key must be an object');
  }
  return PlaybackSourceSnapshot.fromJson(value, parent: '$parent.$key');
}

PlaybackStreamSnapshot? readOptionalPlaybackStream(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$parent.$key must be an object');
  }
  return PlaybackStreamSnapshot.fromJson(value, parent: '$parent.$key');
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$parent.$key must be a non-empty string');
  }
  return value;
}

String _readOptionalString(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('$parent.$key must be a string');
  }
  return value;
}

String? _readNullableString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a string when present');
  }
  return value;
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! bool) {
    throw FormatException('$parent.$key must be a bool');
  }
  return value;
}

int _readInt(Map<String, dynamic> json, String key, {required String parent}) {
  final Object? value = json[key];
  if (value is! int) {
    throw FormatException('$parent.$key must be an int');
  }
  return value;
}

List<PlaybackVariantOptionSnapshot> _readVariantOptions(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value == null) {
    return const <PlaybackVariantOptionSnapshot>[];
  }
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<PlaybackVariantOptionSnapshot>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('$parent.$key must contain only objects');
      }
      return PlaybackVariantOptionSnapshot.fromJson(
        entry,
        parent: '$parent.$key',
      );
    }),
  );
}

List<PlaybackTrackOptionSnapshot> _readTrackOptions(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value == null) {
    return const <PlaybackTrackOptionSnapshot>[];
  }
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<PlaybackTrackOptionSnapshot>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('$parent.$key must contain only objects');
      }
      return PlaybackTrackOptionSnapshot.fromJson(
        entry,
        parent: '$parent.$key',
      );
    }),
  );
}
