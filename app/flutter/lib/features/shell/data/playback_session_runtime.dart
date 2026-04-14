import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/src/rust/api.dart' as rust_api;

abstract class PlaybackSessionRuntimeRepository {
  const PlaybackSessionRuntimeRepository();

  List<PlayerChooserGroup> chooserGroupsForQueueItem(PlayerQueueItem item);

  PlayerSession hydratePlayerSession(PlayerSession session);

  PlayerSession selectPlayerSessionQueueIndex(PlayerSession session, int index);

  PlayerSession selectPlayerSessionChooserOption(
    PlayerSession session,
    PlayerChooserKind kind,
    int optionIndex,
  );

  PlaybackVariantOptionSnapshot? selectedVariantOptionForSession(
    PlayerSession session,
    PlayerChooserKind kind,
  );

  PlaybackTrackOptionSnapshot? selectedTrackOptionForSession(
    PlayerSession session,
    PlayerChooserKind kind,
  );

  String? resolvedPlaybackUriForSession(PlayerSession session);
}

class RustPlaybackSessionRuntimeRepository
    extends PlaybackSessionRuntimeRepository {
  const RustPlaybackSessionRuntimeRepository();

  @override
  List<PlayerChooserGroup> chooserGroupsForQueueItem(PlayerQueueItem item) {
    return _playbackSnapshot(item: item).chooserGroups;
  }

  @override
  PlayerSession hydratePlayerSession(PlayerSession session) {
    final PlayerQueueItem activeItem = session.activeItem;
    final PlaybackSessionRuntimeSnapshot playbackRuntime = _playbackSnapshot(
      item: activeItem,
      chooserGroups: session.chooserGroups,
    );
    return session.copyWith(
      chooserGroups: playbackRuntime.chooserGroups,
      playbackUri:
          playbackRuntime.playbackUri.isEmpty
              ? session.playbackUri
              : playbackRuntime.playbackUri,
    );
  }

  @override
  PlayerSession selectPlayerSessionQueueIndex(
    PlayerSession session,
    int index,
  ) {
    if (index == session.activeIndex) {
      return session;
    }
    final int nextIndex = index.clamp(0, session.queue.length - 1);
    return hydratePlayerSession(session.copyWith(activeIndex: nextIndex));
  }

  @override
  PlayerSession selectPlayerSessionChooserOption(
    PlayerSession session,
    PlayerChooserKind kind,
    int optionIndex,
  ) {
    final List<PlayerChooserGroup> updatedGroups = session.chooserGroups
        .map(
          (PlayerChooserGroup group) =>
              group.kind == kind
                  ? PlayerChooserGroup(
                    kind: group.kind,
                    title: group.title,
                    options: group.options,
                    selectedIndex: optionIndex.clamp(
                      0,
                      group.options.length - 1,
                    ),
                  )
                  : group,
        )
        .toList(growable: false);
    return hydratePlayerSession(session.copyWith(chooserGroups: updatedGroups));
  }

  @override
  String? resolvedPlaybackUriForSession(PlayerSession session) {
    final PlaybackSessionRuntimeSnapshot playbackRuntime = _playbackSnapshot(
      item: session.activeItem,
      chooserGroups: session.chooserGroups,
    );
    return playbackRuntime.playbackUri.isEmpty
        ? session.playbackUri
        : playbackRuntime.playbackUri;
  }

  @override
  PlaybackVariantOptionSnapshot? selectedVariantOptionForSession(
    PlayerSession session,
    PlayerChooserKind kind,
  ) {
    final PlaybackSessionRuntimeSnapshot playbackRuntime = _playbackSnapshot(
      item: session.activeItem,
      chooserGroups: session.chooserGroups,
    );
    return switch (kind) {
      PlayerChooserKind.source => playbackRuntime.selectedSourceOption,
      PlayerChooserKind.quality => playbackRuntime.selectedQualityOption,
      PlayerChooserKind.audio || PlayerChooserKind.subtitles => null,
    };
  }

  @override
  PlaybackTrackOptionSnapshot? selectedTrackOptionForSession(
    PlayerSession session,
    PlayerChooserKind kind,
  ) {
    final PlaybackSessionRuntimeSnapshot playbackRuntime = _playbackSnapshot(
      item: session.activeItem,
      chooserGroups: session.chooserGroups,
    );
    return switch (kind) {
      PlayerChooserKind.audio => playbackRuntime.selectedAudioOption,
      PlayerChooserKind.subtitles => playbackRuntime.selectedSubtitleOption,
      PlayerChooserKind.source || PlayerChooserKind.quality => null,
    };
  }

  PlaybackSessionRuntimeSnapshot _playbackSnapshot({
    required PlayerQueueItem item,
    List<PlayerChooserGroup>? chooserGroups,
  }) {
    final PlaybackStreamSnapshot? stream = item.playbackStream;
    if (stream == null) {
      return const PlaybackSessionRuntimeSnapshot.empty();
    }
    final List<PlayerChooserGroup> groups =
        chooserGroups ?? const <PlayerChooserGroup>[];
    final String json = rust_api.playbackSessionRuntimeJsonFromStreamJson(
      playbackStreamJson: jsonEncode(_playbackStreamToJson(stream)),
      sourceIndex: _selectedChooserIndex(groups, PlayerChooserKind.source),
      qualityIndex: _selectedChooserIndex(groups, PlayerChooserKind.quality),
      audioIndex: _selectedChooserIndex(groups, PlayerChooserKind.audio),
      subtitleIndex: _selectedChooserIndex(groups, PlayerChooserKind.subtitles),
    );
    return PlaybackSessionRuntimeSnapshot.fromJsonString(json);
  }
}

const PlaybackSessionRuntimeRepository
_defaultPlaybackSessionRuntimeRepository =
    RustPlaybackSessionRuntimeRepository();

PlayerSession hydratePlayerSession(PlayerSession session) =>
    _defaultPlaybackSessionRuntimeRepository.hydratePlayerSession(session);

PlayerSession selectPlayerSessionQueueIndex(PlayerSession session, int index) {
  return _defaultPlaybackSessionRuntimeRepository.selectPlayerSessionQueueIndex(
    session,
    index,
  );
}

PlayerSession selectPlayerSessionChooserOption(
  PlayerSession session,
  PlayerChooserKind kind,
  int optionIndex,
) {
  return _defaultPlaybackSessionRuntimeRepository
      .selectPlayerSessionChooserOption(session, kind, optionIndex);
}

List<PlayerChooserGroup> chooserGroupsForQueueItem(PlayerQueueItem item) =>
    _defaultPlaybackSessionRuntimeRepository.chooserGroupsForQueueItem(item);

String? resolvedPlaybackUriForSession(PlayerSession session) =>
    _defaultPlaybackSessionRuntimeRepository.resolvedPlaybackUriForSession(
      session,
    );

PlaybackVariantOptionSnapshot? selectedVariantOptionForSession(
  PlayerSession session,
  PlayerChooserKind kind,
) => _defaultPlaybackSessionRuntimeRepository.selectedVariantOptionForSession(
  session,
  kind,
);

PlaybackTrackOptionSnapshot? selectedTrackOptionForSession(
  PlayerSession session,
  PlayerChooserKind kind,
) => _defaultPlaybackSessionRuntimeRepository.selectedTrackOptionForSession(
  session,
  kind,
);

int _selectedChooserIndex(
  List<PlayerChooserGroup> groups,
  PlayerChooserKind kind,
) {
  for (final PlayerChooserGroup group in groups) {
    if (group.kind == kind) {
      return group.selectedIndex;
    }
  }
  return 0;
}

Map<String, dynamic> _playbackStreamToJson(PlaybackStreamSnapshot stream) {
  return <String, dynamic>{
    'uri': stream.uri,
    'transport': stream.transport,
    'live': stream.live,
    'seekable': stream.seekable,
    'resume_position_seconds': stream.resumePositionSeconds,
    'source_options': stream.sourceOptions
        .map(_playbackVariantOptionToJson)
        .toList(growable: false),
    'quality_options': stream.qualityOptions
        .map(_playbackVariantOptionToJson)
        .toList(growable: false),
    'audio_options': stream.audioOptions
        .map(_playbackTrackOptionToJson)
        .toList(growable: false),
    'subtitle_options': stream.subtitleOptions
        .map(_playbackTrackOptionToJson)
        .toList(growable: false),
  };
}

Map<String, dynamic> _playbackVariantOptionToJson(
  PlaybackVariantOptionSnapshot option,
) {
  return <String, dynamic>{
    'id': option.id,
    'label': option.label,
    'uri': option.uri,
    'transport': option.transport,
    'live': option.live,
    'seekable': option.seekable,
    'resume_position_seconds': option.resumePositionSeconds,
  };
}

Map<String, dynamic> _playbackTrackOptionToJson(
  PlaybackTrackOptionSnapshot option,
) {
  return <String, dynamic>{
    'id': option.id,
    'label': option.label,
    'uri': option.uri,
    'language': option.language,
  };
}

final class PlaybackSessionRuntimeSnapshot {
  const PlaybackSessionRuntimeSnapshot({
    required this.playbackUri,
    required this.chooserGroups,
    required this.selectedSourceOption,
    required this.selectedQualityOption,
    required this.selectedAudioOption,
    required this.selectedSubtitleOption,
  });

  const PlaybackSessionRuntimeSnapshot.empty()
    : playbackUri = '',
      chooserGroups = const <PlayerChooserGroup>[],
      selectedSourceOption = null,
      selectedQualityOption = null,
      selectedAudioOption = null,
      selectedSubtitleOption = null;

  factory PlaybackSessionRuntimeSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'playback session runtime must be a JSON object',
      );
    }
    return PlaybackSessionRuntimeSnapshot.fromJson(decoded);
  }

  factory PlaybackSessionRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return PlaybackSessionRuntimeSnapshot(
      playbackUri: _readString(json, 'playback_uri'),
      chooserGroups: _readChooserGroups(json, 'chooser_groups'),
      selectedSourceOption: _readOptionalVariantOption(
        json,
        'selected_source_option',
      ),
      selectedQualityOption: _readOptionalVariantOption(
        json,
        'selected_quality_option',
      ),
      selectedAudioOption: _readOptionalTrackOption(
        json,
        'selected_audio_option',
      ),
      selectedSubtitleOption: _readOptionalTrackOption(
        json,
        'selected_subtitle_option',
      ),
    );
  }

  final String playbackUri;
  final List<PlayerChooserGroup> chooserGroups;
  final PlaybackVariantOptionSnapshot? selectedSourceOption;
  final PlaybackVariantOptionSnapshot? selectedQualityOption;
  final PlaybackTrackOptionSnapshot? selectedAudioOption;
  final PlaybackTrackOptionSnapshot? selectedSubtitleOption;
}

List<PlayerChooserGroup> _readChooserGroups(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  return List<PlayerChooserGroup>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('$key must contain only objects');
      }
      return PlayerChooserGroup(
        kind: _readChooserKind(entry, 'kind'),
        title: _readString(entry, 'title'),
        options: _readChooserOptions(entry),
        selectedIndex: _readInt(entry, 'selected_index'),
      );
    }),
  );
}

List<PlayerChooserOption> _readChooserOptions(Map<String, dynamic> json) {
  final Object? value = json['options'];
  if (value is! List<Object?>) {
    throw const FormatException('options must be an array');
  }
  return List<PlayerChooserOption>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('options must contain only objects');
      }
      return PlayerChooserOption(
        id: _readString(entry, 'id'),
        label: _readString(entry, 'label'),
      );
    }),
  );
}

PlaybackVariantOptionSnapshot? _readOptionalVariantOption(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  return PlaybackVariantOptionSnapshot.fromJson(value, parent: key);
}

PlaybackTrackOptionSnapshot? _readOptionalTrackOption(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  return PlaybackTrackOptionSnapshot.fromJson(value, parent: key);
}

PlayerChooserKind _readChooserKind(Map<String, dynamic> json, String key) {
  final String value = _readString(json, key);
  return switch (value) {
    'audio' => PlayerChooserKind.audio,
    'subtitles' => PlayerChooserKind.subtitles,
    'quality' => PlayerChooserKind.quality,
    'source' => PlayerChooserKind.source,
    _ => throw FormatException('unsupported chooser kind: $value'),
  };
}

String _readString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

int _readInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an int');
  }
  return value;
}
