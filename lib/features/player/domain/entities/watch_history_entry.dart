import 'package:flutter/foundation.dart';

import '../../../../core/constants.dart';

/// A playback history entry for resume support.
///
/// Domain entity — pure Dart, no infrastructure
/// dependencies. Replaces Drift's DbWatchHistoryData.
@immutable
class WatchHistoryEntry {
  const WatchHistoryEntry({
    required this.id,
    required this.mediaType,
    required this.name,
    required this.streamUrl,
    this.posterUrl,
    this.seriesPosterUrl,
    this.positionMs = 0,
    this.durationMs = 0,
    required this.lastWatched,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.deviceId,
    this.deviceName,
    this.profileId,
    this.sourceId,
  });

  /// Unique history entry identifier.
  final String id;

  /// Content type: "channel", "movie", or "episode".
  final String mediaType;

  /// Display name of the watched content.
  final String name;

  /// Stream URL that was playing.
  final String streamUrl;

  /// Poster image URL for the history list.
  final String? posterUrl;

  /// Series poster fallback URL.
  final String? seriesPosterUrl;

  /// Playback position in milliseconds.
  final int positionMs;

  /// Total duration in milliseconds.
  final int durationMs;

  /// When this content was last watched.
  final DateTime lastWatched;

  /// Parent series ID (for episodes).
  final String? seriesId;

  /// Season number (for episodes).
  final int? seasonNumber;

  /// Episode number (for episodes).
  final int? episodeNumber;

  /// Device ID for multi-device sync.
  final String? deviceId;

  /// Human-readable device name.
  final String? deviceName;

  /// Profile ID that watched this content.
  final String? profileId;

  /// Source ID that provided this content (for multi-source tracking).
  final String? sourceId;

  /// Playback progress as a fraction (0.0 – 1.0).
  double get progress => durationMs > 0 ? positionMs / durationMs : 0.0;

  /// Whether playback is nearly complete (>= 95%).
  bool get isNearlyComplete => progress >= kCompletionThreshold;

  /// Short episode label for series items, e.g. "S2 E5".
  ///
  /// Returns null when [seasonNumber] or [episodeNumber] is missing.
  String? get episodeLabel {
    if (seasonNumber == null || episodeNumber == null) return null;
    return 'S$seasonNumber E$episodeNumber';
  }

  /// Returns a display label like "S2 E5 · 15m left" or "23m left".
  String get remainingLabel {
    final parts = <String>[];
    final ep = episodeLabel;
    if (ep != null) parts.add(ep);
    if (durationMs > 0 && positionMs < durationMs) {
      final remainMs = durationMs - positionMs;
      final remainMin = (remainMs / 60000).ceil();
      parts.add('${remainMin}m left');
    }
    return parts.join(' · ');
  }

  WatchHistoryEntry copyWith({
    String? id,
    String? mediaType,
    String? name,
    String? streamUrl,
    String? posterUrl,
    String? seriesPosterUrl,
    int? positionMs,
    int? durationMs,
    DateTime? lastWatched,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    String? deviceId,
    String? deviceName,
    String? profileId,
    String? sourceId,
  }) {
    return WatchHistoryEntry(
      id: id ?? this.id,
      mediaType: mediaType ?? this.mediaType,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      posterUrl: posterUrl ?? this.posterUrl,
      seriesPosterUrl: seriesPosterUrl ?? this.seriesPosterUrl,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      lastWatched: lastWatched ?? this.lastWatched,
      seriesId: seriesId ?? this.seriesId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      profileId: profileId ?? this.profileId,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'WatchHistoryEntry($name, $mediaType)';
}
