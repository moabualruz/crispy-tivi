import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:flutter/foundation.dart';

@immutable
final class PersonalizationRuntimeSnapshot {
  const PersonalizationRuntimeSnapshot({
    required this.title,
    required this.version,
    required this.startupRoute,
    required this.continueWatching,
    required this.recentlyViewed,
    required this.favoriteMediaKeys,
    required this.favoriteChannelNumbers,
    required this.notes,
  });

  const PersonalizationRuntimeSnapshot.empty()
    : title = 'CrispyTivi Personalization Runtime',
      version = '0',
      startupRoute = 'Home',
      continueWatching = const <PersistentPlaybackEntry>[],
      recentlyViewed = const <PersistentPlaybackEntry>[],
      favoriteMediaKeys = const <String>[],
      favoriteChannelNumbers = const <String>[],
      notes = const <String>[];

  factory PersonalizationRuntimeSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'personalization runtime must be a JSON object',
      );
    }
    return PersonalizationRuntimeSnapshot.fromJson(decoded);
  }

  factory PersonalizationRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return PersonalizationRuntimeSnapshot(
      title: _readString(json, 'title', parent: 'personalization_runtime'),
      version: _readString(json, 'version', parent: 'personalization_runtime'),
      startupRoute: _readString(
        json,
        'startup_route',
        parent: 'personalization_runtime',
      ),
      continueWatching: _readEntries(
        json,
        'continue_watching',
        parent: 'personalization_runtime',
      ),
      recentlyViewed: _readEntries(
        json,
        'recently_viewed',
        parent: 'personalization_runtime',
      ),
      favoriteMediaKeys: _readStringList(
        json,
        'favorite_media_keys',
        parent: 'personalization_runtime',
      ),
      favoriteChannelNumbers: _readStringList(
        json,
        'favorite_channel_numbers',
        parent: 'personalization_runtime',
      ),
      notes: _readOptionalStringList(json, 'notes'),
    );
  }

  final String title;
  final String version;
  final String startupRoute;
  final List<PersistentPlaybackEntry> continueWatching;
  final List<PersistentPlaybackEntry> recentlyViewed;
  final List<String> favoriteMediaKeys;
  final List<String> favoriteChannelNumbers;
  final List<String> notes;

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'version': version,
      'startup_route': startupRoute,
      'continue_watching': continueWatching
          .map((PersistentPlaybackEntry entry) => entry.toJson())
          .toList(growable: false),
      'recently_viewed': recentlyViewed
          .map((PersistentPlaybackEntry entry) => entry.toJson())
          .toList(growable: false),
      'favorite_media_keys': favoriteMediaKeys,
      'favorite_channel_numbers': favoriteChannelNumbers,
      'notes': notes,
    };
  }

  PersonalizationRuntimeSnapshot copyWith({
    String? startupRoute,
    List<PersistentPlaybackEntry>? continueWatching,
    List<PersistentPlaybackEntry>? recentlyViewed,
    List<String>? favoriteMediaKeys,
    List<String>? favoriteChannelNumbers,
    List<String>? notes,
  }) {
    return PersonalizationRuntimeSnapshot(
      title: title,
      version: version,
      startupRoute: startupRoute ?? this.startupRoute,
      continueWatching: continueWatching ?? this.continueWatching,
      recentlyViewed: recentlyViewed ?? this.recentlyViewed,
      favoriteMediaKeys: favoriteMediaKeys ?? this.favoriteMediaKeys,
      favoriteChannelNumbers:
          favoriteChannelNumbers ?? this.favoriteChannelNumbers,
      notes: notes ?? this.notes,
    );
  }

  List<PersistentPlaybackEntry> entriesForMovieContinueWatching() {
    return continueWatching
        .where(
          (PersistentPlaybackEntry entry) =>
              entry.kind == PersistentPlaybackKind.movie,
        )
        .toList(growable: false);
  }

  List<PersistentPlaybackEntry> entriesForSeriesContinueWatching() {
    return continueWatching
        .where(
          (PersistentPlaybackEntry entry) =>
              entry.kind == PersistentPlaybackKind.series ||
              entry.kind == PersistentPlaybackKind.episode,
        )
        .toList(growable: false);
  }

  List<PersistentPlaybackEntry> entriesForRecentMovies() {
    return recentlyViewed
        .where(
          (PersistentPlaybackEntry entry) =>
              entry.kind == PersistentPlaybackKind.movie,
        )
        .toList(growable: false);
  }

  List<PersistentPlaybackEntry> entriesForRecentSeries() {
    return recentlyViewed
        .where(
          (PersistentPlaybackEntry entry) =>
              entry.kind == PersistentPlaybackKind.series ||
              entry.kind == PersistentPlaybackKind.episode,
        )
        .toList(growable: false);
  }

  List<PersistentPlaybackEntry> entriesForWatchlistMovies() {
    return recentlyViewed
        .where(
          (PersistentPlaybackEntry entry) =>
              entry.kind == PersistentPlaybackKind.movie &&
              favoriteMediaKeys.contains(entry.contentKey),
        )
        .toList(growable: false);
  }

  List<PersistentPlaybackEntry> entriesForWatchlistSeries() {
    return recentlyViewed
        .where(
          (PersistentPlaybackEntry entry) =>
              (entry.kind == PersistentPlaybackKind.series ||
                  entry.kind == PersistentPlaybackKind.episode) &&
              favoriteMediaKeys.contains(entry.contentKey),
        )
        .toList(growable: false);
  }

  bool isFavoriteMediaKey(String contentKey) {
    return favoriteMediaKeys.contains(contentKey);
  }

  PersonalizationRuntimeSnapshot updateStartupRoute(String route) {
    return copyWith(startupRoute: route);
  }

  PersonalizationRuntimeSnapshot toggleFavoriteMediaKey(String contentKey) {
    final List<String> next = List<String>.from(favoriteMediaKeys);
    if (next.contains(contentKey)) {
      next.remove(contentKey);
    } else {
      next.add(contentKey);
    }
    return copyWith(favoriteMediaKeys: List<String>.unmodifiable(next));
  }

  PersonalizationRuntimeSnapshot recordPlayback(PersistentPlaybackEntry entry) {
    List<PersistentPlaybackEntry> dedupe(
      List<PersistentPlaybackEntry> entries, {
      required int maxItems,
      required bool continueOnly,
    }) {
      final List<PersistentPlaybackEntry> filtered = entries
          .where((PersistentPlaybackEntry item) {
            if (item.contentKey == entry.contentKey &&
                item.kind == entry.kind &&
                item.channelNumber == entry.channelNumber) {
              return false;
            }
            return continueOnly ? item.progressValue > 0 : true;
          })
          .toList(growable: true);
      filtered.insert(0, entry);
      if (continueOnly) {
        filtered.removeWhere(
          (PersistentPlaybackEntry item) => item.progressValue <= 0,
        );
      }
      if (filtered.length > maxItems) {
        filtered.removeRange(maxItems, filtered.length);
      }
      return List<PersistentPlaybackEntry>.unmodifiable(filtered);
    }

    return copyWith(
      continueWatching: dedupe(
        continueWatching,
        maxItems: 8,
        continueOnly: true,
      ),
      recentlyViewed: dedupe(recentlyViewed, maxItems: 12, continueOnly: false),
    );
  }
}

enum PersistentPlaybackKind { live, movie, series, episode }

@immutable
final class PersistentPlaybackEntry {
  const PersistentPlaybackEntry({
    required this.kind,
    required this.contentKey,
    required this.title,
    required this.caption,
    required this.summary,
    required this.progressLabel,
    required this.progressValue,
    required this.resumePositionSeconds,
    required this.lastViewedAt,
    required this.detailLines,
    this.channelNumber,
    this.artwork,
    this.playbackSource,
    this.playbackStream,
  });

  factory PersistentPlaybackEntry.fromJson(
    Map<String, dynamic> json, {
    required String parent,
  }) {
    return PersistentPlaybackEntry(
      kind: _readKind(_readString(json, 'kind', parent: parent)),
      contentKey: _readString(json, 'content_key', parent: parent),
      channelNumber: _readNullableString(json, 'channel_number'),
      title: _readString(json, 'title', parent: parent),
      caption: _readString(json, 'caption', parent: parent),
      summary: _readString(json, 'summary', parent: parent),
      progressLabel: _readString(json, 'progress_label', parent: parent),
      progressValue: _readDouble(json, 'progress_value', parent: parent),
      resumePositionSeconds: _readInt(
        json,
        'resume_position_seconds',
        parent: parent,
      ),
      lastViewedAt: _readString(json, 'last_viewed_at', parent: parent),
      detailLines: _readStringList(json, 'detail_lines', parent: parent),
      artwork: _readOptionalArtworkSource(json, 'artwork'),
      playbackSource: readOptionalPlaybackSource(
        json,
        'playback_source',
        parent: parent,
      ),
      playbackStream: readOptionalPlaybackStream(
        json,
        'playback_stream',
        parent: parent,
      ),
    );
  }

  final PersistentPlaybackKind kind;
  final String contentKey;
  final String? channelNumber;
  final String title;
  final String caption;
  final String summary;
  final String progressLabel;
  final double progressValue;
  final int resumePositionSeconds;
  final String lastViewedAt;
  final List<String> detailLines;
  final ArtworkSource? artwork;
  final PlaybackSourceSnapshot? playbackSource;
  final PlaybackStreamSnapshot? playbackStream;

  ShelfItem toShelfItem() {
    return ShelfItem(title: title, caption: caption, artwork: artwork);
  }

  PersistentPlaybackEntry copyWith({
    String? progressLabel,
    double? progressValue,
    int? resumePositionSeconds,
    String? lastViewedAt,
  }) {
    return PersistentPlaybackEntry(
      kind: kind,
      contentKey: contentKey,
      channelNumber: channelNumber,
      title: title,
      caption: caption,
      summary: summary,
      progressLabel: progressLabel ?? this.progressLabel,
      progressValue: progressValue ?? this.progressValue,
      resumePositionSeconds:
          resumePositionSeconds ?? this.resumePositionSeconds,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      detailLines: detailLines,
      artwork: artwork,
      playbackSource: playbackSource,
      playbackStream:
          playbackStream == null
              ? null
              : PlaybackStreamSnapshot(
                uri: playbackStream!.uri,
                transport: playbackStream!.transport,
                live: playbackStream!.live,
                seekable: playbackStream!.seekable,
                resumePositionSeconds:
                    resumePositionSeconds ?? this.resumePositionSeconds,
                sourceOptions: playbackStream!.sourceOptions,
                qualityOptions: playbackStream!.qualityOptions,
                audioOptions: playbackStream!.audioOptions,
                subtitleOptions: playbackStream!.subtitleOptions,
              ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'content_key': contentKey,
      if (channelNumber != null) 'channel_number': channelNumber,
      'title': title,
      'caption': caption,
      'summary': summary,
      'progress_label': progressLabel,
      'progress_value': progressValue,
      'resume_position_seconds': resumePositionSeconds,
      'last_viewed_at': lastViewedAt,
      'detail_lines': detailLines,
      if (artwork != null)
        'artwork': <String, dynamic>{
          'kind': artwork!.kind.name,
          'value': artwork!.value,
        },
      if (playbackSource != null)
        'playback_source': <String, dynamic>{
          'kind': playbackSource!.kind,
          'source_key': playbackSource!.sourceKey,
          'content_key': playbackSource!.contentKey,
          'source_label': playbackSource!.sourceLabel,
          'handoff_label': playbackSource!.handoffLabel,
        },
      if (playbackStream != null)
        'playback_stream': <String, dynamic>{
          'uri': playbackStream!.uri,
          'transport': playbackStream!.transport,
          'live': playbackStream!.live,
          'seekable': playbackStream!.seekable,
          'resume_position_seconds': playbackStream!.resumePositionSeconds,
          'source_options': playbackStream!.sourceOptions
              .map(
                (PlaybackVariantOptionSnapshot option) => <String, dynamic>{
                  'id': option.id,
                  'label': option.label,
                  'uri': option.uri,
                  'transport': option.transport,
                  'live': option.live,
                  'seekable': option.seekable,
                  'resume_position_seconds': option.resumePositionSeconds,
                },
              )
              .toList(growable: false),
          'quality_options': playbackStream!.qualityOptions
              .map(
                (PlaybackVariantOptionSnapshot option) => <String, dynamic>{
                  'id': option.id,
                  'label': option.label,
                  'uri': option.uri,
                  'transport': option.transport,
                  'live': option.live,
                  'seekable': option.seekable,
                  'resume_position_seconds': option.resumePositionSeconds,
                },
              )
              .toList(growable: false),
          'audio_options': playbackStream!.audioOptions
              .map(
                (PlaybackTrackOptionSnapshot option) => <String, dynamic>{
                  'id': option.id,
                  'label': option.label,
                  'uri': option.uri,
                  if (option.language != null) 'language': option.language,
                },
              )
              .toList(growable: false),
          'subtitle_options': playbackStream!.subtitleOptions
              .map(
                (PlaybackTrackOptionSnapshot option) => <String, dynamic>{
                  'id': option.id,
                  'label': option.label,
                  'uri': option.uri,
                  if (option.language != null) 'language': option.language,
                },
              )
              .toList(growable: false),
        },
    };
  }
}

PersistentPlaybackKind _readKind(String value) {
  return switch (value) {
    'live' => PersistentPlaybackKind.live,
    'movie' => PersistentPlaybackKind.movie,
    'series' => PersistentPlaybackKind.series,
    'episode' => PersistentPlaybackKind.episode,
    _ => throw FormatException('unsupported persistent playback kind: $value'),
  };
}

List<PersistentPlaybackEntry> _readEntries(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<PersistentPlaybackEntry>.unmodifiable(
    value.map((Object? item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$parent.$key must contain only objects');
      }
      return PersistentPlaybackEntry.fromJson(item, parent: '$parent.$key');
    }),
  );
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

int _readInt(Map<String, dynamic> json, String key, {required String parent}) {
  final Object? value = json[key];
  if (value is! int) {
    throw FormatException('$parent.$key must be an int');
  }
  return value;
}

double _readDouble(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is int) {
    return value.toDouble();
  }
  if (value is! double) {
    throw FormatException('$parent.$key must be a number');
  }
  return value;
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
    value.map((Object? item) {
      if (item is! String || item.isEmpty) {
        throw FormatException('$parent.$key must contain only strings');
      }
      return item;
    }),
  );
}

List<String> _readOptionalStringList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array when present');
  }
  return List<String>.unmodifiable(
    value.map((Object? item) {
      if (item is! String || item.isEmpty) {
        throw FormatException('$key must contain only non-empty strings');
      }
      return item;
    }),
  );
}
