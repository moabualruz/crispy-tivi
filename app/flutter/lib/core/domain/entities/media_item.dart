import 'package:equatable/equatable.dart';

import '../mixins/playback_progress_mixin.dart';
import 'media_type.dart';

/// Represents a playable item or container in a media source.
///
/// This is a generic abstraction over IPTV channels, VOD movies,
/// and Jellyfin/Emby/Plex library items.
class MediaItem extends Equatable with PlaybackProgressMixin {
  const MediaItem({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.logoUrl,
    this.overview,
    this.releaseDate,
    this.rating,
    this.durationMs,
    this.streamUrl,
    this.metadata = const {},
    this.playbackPositionMs,
    this.isWatched = false,
  });

  /// Year derived from releaseDate.
  int? get year => releaseDate?.year;

  /// Unique identifier within the source.
  final String id;

  /// Display name (title).
  final String name;

  /// Type of media (movie, series, folder, etc.).
  final MediaType type;

  /// ID of the parent folder/library (if hierarchy exists).
  final String? parentId;

  /// URL to cover art or logo.
  final String? logoUrl;

  /// Description or summary.
  final String? overview;

  /// Release date or air date.
  final DateTime? releaseDate;

  /// Content rating (e.g., PG-13).
  final String? rating;

  /// Duration in milliseconds (for playable items).
  final int? durationMs;

  /// Direct stream URL if available immediately.
  /// Some sources might require a separate call to fetch this.
  final String? streamUrl;

  /// Additional source-specific metadata (arbitrary).
  final Map<String, dynamic> metadata;

  /// Playback position in milliseconds (for resume functionality).
  /// Null means not started or position unknown.
  @override
  final int? playbackPositionMs;

  /// Whether this item has been fully watched.
  @override
  final bool isWatched;

  /// Returns the watch progress as a value between 0.0 and 1.0.
  /// Returns null if duration or position is unknown.
  double? get watchProgress {
    if (playbackPositionMs == null || durationMs == null || durationMs == 0) {
      return null;
    }
    return (playbackPositionMs! / durationMs!).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    parentId,
    logoUrl,
    overview,
    releaseDate,
    rating,
    durationMs,
    streamUrl,
    metadata,
    playbackPositionMs,
    isWatched,
  ];
}
