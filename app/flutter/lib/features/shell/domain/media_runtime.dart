import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';

final class MediaRuntimeSnapshot {
  const MediaRuntimeSnapshot({
    required this.title,
    required this.version,
    required this.activePanel,
    required this.activeScope,
    required this.movieHero,
    required this.seriesHero,
    required this.movieCollections,
    required this.seriesCollections,
    required this.seriesDetail,
    required this.notes,
  });

  const MediaRuntimeSnapshot.empty()
    : title = 'CrispyTivi Media Runtime',
      version = '0',
      activePanel = 'Movies',
      activeScope = 'Featured',
      movieHero = const MediaRuntimeHeroSnapshot.empty(),
      seriesHero = const MediaRuntimeHeroSnapshot.empty(),
      movieCollections = const <MediaRuntimeCollectionSnapshot>[],
      seriesCollections = const <MediaRuntimeCollectionSnapshot>[],
      seriesDetail = const MediaRuntimeSeriesDetailSnapshot.empty(),
      notes = const <String>[];

  factory MediaRuntimeSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('media runtime must be a JSON object');
    }
    return MediaRuntimeSnapshot.fromJson(decoded);
  }

  factory MediaRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return MediaRuntimeSnapshot(
      title: _readString(json, 'title', parent: 'media_runtime'),
      version: _readString(json, 'version', parent: 'media_runtime'),
      activePanel: _readString(json, 'active_panel', parent: 'media_runtime'),
      activeScope: _readString(json, 'active_scope', parent: 'media_runtime'),
      movieHero: MediaRuntimeHeroSnapshot.fromJson(
        _readObject(json, 'movie_hero', parent: 'media_runtime'),
      ),
      seriesHero: MediaRuntimeHeroSnapshot.fromJson(
        _readObject(json, 'series_hero', parent: 'media_runtime'),
      ),
      movieCollections: _readCollections(json, 'movie_collections'),
      seriesCollections: _readCollections(json, 'series_collections'),
      seriesDetail: MediaRuntimeSeriesDetailSnapshot.fromJson(
        _readObject(json, 'series_detail', parent: 'media_runtime'),
      ),
      notes: _readStringList(json, 'notes', parent: 'media_runtime'),
    );
  }

  final String title;
  final String version;
  final String activePanel;
  final String activeScope;
  final MediaRuntimeHeroSnapshot movieHero;
  final MediaRuntimeHeroSnapshot seriesHero;
  final List<MediaRuntimeCollectionSnapshot> movieCollections;
  final List<MediaRuntimeCollectionSnapshot> seriesCollections;
  final MediaRuntimeSeriesDetailSnapshot seriesDetail;
  final List<String> notes;
}

final class MediaRuntimeHeroSnapshot {
  const MediaRuntimeHeroSnapshot({
    required this.kicker,
    required this.title,
    required this.summary,
    required this.primaryAction,
    required this.secondaryAction,
    this.artwork,
  });

  const MediaRuntimeHeroSnapshot.empty()
    : kicker = '',
      title = '',
      summary = '',
      primaryAction = '',
      secondaryAction = '',
      artwork = null;

  factory MediaRuntimeHeroSnapshot.fromJson(Map<String, dynamic> json) {
    return MediaRuntimeHeroSnapshot(
      kicker: _readString(json, 'kicker', parent: 'hero'),
      title: _readString(json, 'title', parent: 'hero'),
      summary: _readString(json, 'summary', parent: 'hero'),
      primaryAction: _readString(json, 'primary_action', parent: 'hero'),
      secondaryAction: _readString(json, 'secondary_action', parent: 'hero'),
      artwork: _readOptionalArtworkSource(json, 'artwork'),
    );
  }

  final String kicker;
  final String title;
  final String summary;
  final String primaryAction;
  final String secondaryAction;
  final ArtworkSource? artwork;
}

final class MediaRuntimeCollectionSnapshot {
  const MediaRuntimeCollectionSnapshot({
    required this.title,
    required this.summary,
    required this.items,
  });

  final String title;
  final String summary;
  final List<MediaRuntimeItemSnapshot> items;
}

final class MediaRuntimeItemSnapshot {
  const MediaRuntimeItemSnapshot({
    required this.title,
    required this.caption,
    this.rank,
    this.artwork,
    this.playbackSource,
    this.playbackStream,
  });

  final String title;
  final String caption;
  final int? rank;
  final ArtworkSource? artwork;
  final PlaybackSourceSnapshot? playbackSource;
  final PlaybackStreamSnapshot? playbackStream;
}

final class MediaRuntimeSeriesDetailSnapshot {
  const MediaRuntimeSeriesDetailSnapshot({
    required this.summaryTitle,
    required this.summaryBody,
    required this.handoffLabel,
    required this.seasons,
  });

  const MediaRuntimeSeriesDetailSnapshot.empty()
    : summaryTitle = '',
      summaryBody = '',
      handoffLabel = '',
      seasons = const <MediaRuntimeSeasonSnapshot>[];

  factory MediaRuntimeSeriesDetailSnapshot.fromJson(Map<String, dynamic> json) {
    return MediaRuntimeSeriesDetailSnapshot(
      summaryTitle: _readString(json, 'summary_title', parent: 'series_detail'),
      summaryBody: _readString(json, 'summary_body', parent: 'series_detail'),
      handoffLabel: _readString(json, 'handoff_label', parent: 'series_detail'),
      seasons: _readSeasons(json, 'seasons'),
    );
  }

  final String summaryTitle;
  final String summaryBody;
  final String handoffLabel;
  final List<MediaRuntimeSeasonSnapshot> seasons;
}

final class MediaRuntimeSeasonSnapshot {
  const MediaRuntimeSeasonSnapshot({
    required this.label,
    required this.summary,
    required this.episodes,
  });

  final String label;
  final String summary;
  final List<MediaRuntimeEpisodeSnapshot> episodes;
}

final class MediaRuntimeEpisodeSnapshot {
  const MediaRuntimeEpisodeSnapshot({
    required this.code,
    required this.title,
    required this.summary,
    required this.durationLabel,
    required this.handoffLabel,
    this.playbackSource,
    this.playbackStream,
  });

  final String code;
  final String title;
  final String summary;
  final String durationLabel;
  final String handoffLabel;
  final PlaybackSourceSnapshot? playbackSource;
  final PlaybackStreamSnapshot? playbackStream;
}

List<MediaRuntimeCollectionSnapshot> _readCollections(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  if (value.isEmpty) {
    return const <MediaRuntimeCollectionSnapshot>[];
  }
  return List<MediaRuntimeCollectionSnapshot>.unmodifiable(
    value.map((Object? item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$key must contain only objects');
      }
      final Object? items = item['items'];
      if (items is! List<Object?> || items.isEmpty) {
        throw FormatException('$key.items must be a non-empty array');
      }
      return MediaRuntimeCollectionSnapshot(
        title: _readString(item, 'title', parent: key),
        summary: _readString(item, 'summary', parent: key),
        items: List<MediaRuntimeItemSnapshot>.unmodifiable(
          items.map((Object? entry) {
            if (entry is! Map<String, dynamic>) {
              throw FormatException('$key.items must contain only objects');
            }
            return MediaRuntimeItemSnapshot(
              title: _readString(entry, 'title', parent: '$key.items'),
              caption: _readString(entry, 'caption', parent: '$key.items'),
              rank: _readOptionalInt(entry, 'rank'),
              artwork: _readOptionalArtworkSource(entry, 'artwork'),
              playbackSource: readOptionalPlaybackSource(
                entry,
                'playback_source',
                parent: '$key.items',
              ),
              playbackStream: readOptionalPlaybackStream(
                entry,
                'playback_stream',
                parent: '$key.items',
              ),
            );
          }),
        ),
      );
    }),
  );
}

List<MediaRuntimeSeasonSnapshot> _readSeasons(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  if (value.isEmpty) {
    return const <MediaRuntimeSeasonSnapshot>[];
  }
  return List<MediaRuntimeSeasonSnapshot>.unmodifiable(
    value.map((Object? item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$key must contain only objects');
      }
      final Object? episodes = item['episodes'];
      if (episodes is! List<Object?> || episodes.isEmpty) {
        throw FormatException('$key.episodes must be a non-empty array');
      }
      return MediaRuntimeSeasonSnapshot(
        label: _readString(item, 'label', parent: key),
        summary: _readString(item, 'summary', parent: key),
        episodes: List<MediaRuntimeEpisodeSnapshot>.unmodifiable(
          episodes.map((Object? entry) {
            if (entry is! Map<String, dynamic>) {
              throw FormatException('$key.episodes must contain only objects');
            }
            return MediaRuntimeEpisodeSnapshot(
              code: _readString(entry, 'code', parent: '$key.episodes'),
              title: _readString(entry, 'title', parent: '$key.episodes'),
              summary: _readString(entry, 'summary', parent: '$key.episodes'),
              durationLabel: _readString(
                entry,
                'duration_label',
                parent: '$key.episodes',
              ),
              handoffLabel: _readString(
                entry,
                'handoff_label',
                parent: '$key.episodes',
              ),
              playbackSource: readOptionalPlaybackSource(
                entry,
                'playback_source',
                parent: '$key.episodes',
              ),
              playbackStream: readOptionalPlaybackStream(
                entry,
                'playback_stream',
                parent: '$key.episodes',
              ),
            );
          }),
        ),
      );
    }),
  );
}

Map<String, dynamic> _readObject(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$parent.$key must be an object');
  }
  return value;
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

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('$key must be an int');
  }
  return value;
}

ArtworkSource? _readOptionalArtworkSource(
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
  final String kind = _readString(value, 'kind', parent: key);
  final String source = _readString(value, 'value', parent: key);
  return switch (kind) {
    'asset' => ArtworkSource.asset(source),
    'network' => ArtworkSource.network(source),
    _ => throw FormatException('$key.kind must be asset or network'),
  };
}

List<String> _readStringList(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<String>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! String || entry.isEmpty) {
        throw FormatException('$parent.$key must contain only strings');
      }
      return entry;
    }),
  );
}
