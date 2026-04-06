import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';

// ─────────────────────────────────────────────────────────────
//  PlaybackSessionState
// ─────────────────────────────────────────────────────────────

/// Holds all metadata for the current (or most recent)
/// playback session.
///
/// All fields are optional except [streamUrl] which
/// defaults to the empty string when no session is active.
class PlaybackSessionState {
  const PlaybackSessionState({
    this.streamUrl = '',
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

  /// Returns a copy of this state with the given fields
  /// replaced.
  PlaybackSessionState copyWith({
    String? streamUrl,
    bool? isLive,
    String? channelName,
    String? channelLogoUrl,
    String? currentProgram,
    Map<String, String>? headers,
    List<Channel>? channelList,
    int? channelIndex,
    Duration? startPosition,
    String? mediaType,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    List<VodItem>? episodeList,
    String? posterUrl,
    String? seriesPosterUrl,
    String? sourceId,
  }) {
    return PlaybackSessionState(
      streamUrl: streamUrl ?? this.streamUrl,
      isLive: isLive ?? this.isLive,
      channelName: channelName ?? this.channelName,
      channelLogoUrl: channelLogoUrl ?? this.channelLogoUrl,
      currentProgram: currentProgram ?? this.currentProgram,
      headers: headers ?? this.headers,
      channelList: channelList ?? this.channelList,
      channelIndex: channelIndex ?? this.channelIndex,
      startPosition: startPosition ?? this.startPosition,
      mediaType: mediaType ?? this.mediaType,
      seriesId: seriesId ?? this.seriesId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeList: episodeList ?? this.episodeList,
      posterUrl: posterUrl ?? this.posterUrl,
      seriesPosterUrl: seriesPosterUrl ?? this.seriesPosterUrl,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}
