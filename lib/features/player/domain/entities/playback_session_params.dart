import 'package:meta/meta.dart';

import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';

/// Value object that bundles all parameters required to
/// start or preview a playback session.
///
/// Pass a [PlaybackSessionParams] to
/// [PlaybackSessionNotifier.startPlayback] or
/// [PlaybackSessionNotifier.startPreview] instead of
/// spreading individual named parameters at each call site.
///
/// Example:
/// ```dart
/// final params = PlaybackSessionParams(
///   streamUrl: channel.streamUrl,
///   isLive: true,
///   channelName: channel.name,
///   channelLogoUrl: channel.logoUrl,
/// );
/// await ref.read(playbackSessionProvider.notifier)
///     .startPlaybackWithParams(params);
/// ```
@immutable
class PlaybackSessionParams {
  const PlaybackSessionParams({
    required this.streamUrl,
    this.isLive = false,
    this.channelName,
    this.channelLogoUrl,
    this.currentProgram,
    this.headers,
    this.channelList,
    this.channelIndex = 0,
    this.startPosition,
    this.mediaType,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeList,
    this.posterUrl,
    this.seriesPosterUrl,
    this.sourceId,
  });

  /// The HLS / RTSP / RTMP stream URL to play.
  final String streamUrl;

  /// Whether this is a live IPTV stream (vs VOD).
  final bool isLive;

  /// Display name of the channel or movie/episode title.
  final String? channelName;

  /// URL of the channel logo or poster thumbnail.
  final String? channelLogoUrl;

  /// Currently-airing programme name (live TV).
  final String? currentProgram;

  /// Optional HTTP headers forwarded to the stream request.
  final Map<String, String>? headers;

  /// Full ordered channel list used for up/down zapping.
  final List<Channel>? channelList;

  /// Index of the currently playing channel in [channelList].
  final int channelIndex;

  /// Seek position for VOD resume-from-last-position.
  final Duration? startPosition;

  /// Content type: `'movie'`, `'episode'`, `'live'`, etc.
  final String? mediaType;

  /// Series identifier for episode grouping.
  final String? seriesId;

  /// Season number for episode content.
  final int? seasonNumber;

  /// Episode number for episode content.
  final int? episodeNumber;

  /// Ordered episode list used for next-episode auto-play.
  final List<VodItem>? episodeList;

  /// Poster / cover art URL for the current item.
  final String? posterUrl;

  /// Series-level poster URL (different from episode poster).
  final String? seriesPosterUrl;

  /// Source ID for multi-source tracking in watch history.
  final String? sourceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackSessionParams &&
          streamUrl == other.streamUrl &&
          isLive == other.isLive &&
          channelName == other.channelName &&
          channelLogoUrl == other.channelLogoUrl &&
          currentProgram == other.currentProgram &&
          channelIndex == other.channelIndex &&
          startPosition == other.startPosition &&
          mediaType == other.mediaType &&
          seriesId == other.seriesId &&
          seasonNumber == other.seasonNumber &&
          episodeNumber == other.episodeNumber &&
          posterUrl == other.posterUrl &&
          seriesPosterUrl == other.seriesPosterUrl &&
          sourceId == other.sourceId;

  @override
  int get hashCode => Object.hash(
    streamUrl,
    isLive,
    channelName,
    channelLogoUrl,
    currentProgram,
    channelIndex,
    startPosition,
    mediaType,
    seriesId,
    seasonNumber,
    episodeNumber,
    posterUrl,
    seriesPosterUrl,
    sourceId,
  );
}
