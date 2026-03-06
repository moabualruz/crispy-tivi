import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../data/stream_url_resolver.dart';
import '../../domain/entities/playback_session_params.dart';
import 'player_providers.dart';

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
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PlaybackSessionNotifier
// ─────────────────────────────────────────────────────────────

/// Manages the active playback session.
///
/// Calling [startPlayback] both persists all session
/// metadata and triggers video playback via
/// [PlayerService] and a fullscreen mode transition.
///
/// Calling [startPreview] only updates the metadata —
/// useful for EPG which drives its own preview player.
class PlaybackSessionNotifier extends Notifier<PlaybackSessionState> {
  @override
  PlaybackSessionState build() => const PlaybackSessionState();

  /// Guard flag — prevents duplicate play requests while a
  /// startPlayback call is already in flight.
  bool _isPending = false;

  /// Starts a full-screen playback session.
  ///
  /// Persists all session metadata, calls
  /// [PlayerService.play], and transitions the player
  /// mode to [PlayerMode.fullscreen].
  ///
  /// Duplicate calls while a play is already in progress
  /// are silently dropped — the user tapping Play twice
  /// before the player appears should not trigger a
  /// second stream open.
  Future<void> startPlayback({
    required String streamUrl,
    bool isLive = false,
    String? channelName,
    String? channelLogoUrl,
    String? currentProgram,
    Map<String, String>? headers,
    List<Channel>? channelList,
    int channelIndex = 0,
    Duration? startPosition,
    String? mediaType,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    List<VodItem>? episodeList,
    String? posterUrl,
    String? seriesPosterUrl,
  }) async {
    if (_isPending) return;
    _isPending = true;
    try {
      // Resolve synthetic media server URLs (plex://, emby://, jellyfin://)
      // to real HTTP(S) playback URLs before passing to PlayerService.
      // Falls back to the original URL if resolution fails.
      String effectiveUrl = streamUrl;
      Map<String, String>? effectiveHeaders = headers;
      try {
        final sources = ref.read(settingsNotifierProvider).value?.sources ?? [];
        final resolved = await StreamUrlResolver(sources).resolve(streamUrl);
        if (resolved != null) {
          effectiveUrl = resolved.url;
          effectiveHeaders = {...?headers, ...?resolved.headers};
        }
      } catch (e) {
        debugPrint('StreamUrlResolver: failed to resolve $streamUrl: $e');
      }

      state = PlaybackSessionState(
        streamUrl: effectiveUrl,
        isLive: isLive,
        channelName: channelName,
        channelLogoUrl: channelLogoUrl,
        currentProgram: currentProgram,
        headers: effectiveHeaders,
        channelList: channelList,
        channelIndex: channelIndex,
        startPosition: startPosition,
        mediaType: mediaType,
        seriesId: seriesId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeList: episodeList,
        posterUrl: posterUrl,
        seriesPosterUrl: seriesPosterUrl,
      );

      await ref
          .read(playerServiceProvider)
          .play(
            effectiveUrl,
            isLive: isLive,
            channelName: channelName,
            channelLogoUrl: channelLogoUrl,
            currentProgram: currentProgram,
            headers: effectiveHeaders,
          );

      // PS-17: Restore last-used playback speed for VOD.
      // Live TV always plays at 1× — speed memory only
      // applies to on-demand content.
      final savedSpeed = ref.read(lastPlaybackSpeedProvider);
      if (!isLive && savedSpeed != 1.0) {
        await ref.read(playerServiceProvider).setSpeed(savedSpeed);
      } else if (isLive) {
        // Ensure live TV starts at normal speed even if VOD had
        // boosted speed previously.
        await ref.read(playerServiceProvider).setSpeed(1.0);
      }

      ref
          .read(playerModeProvider.notifier)
          .enterFullscreen(
            hostRoute: ref.read(playerModeProvider).currentRoute,
          );
      ref.read(playerServiceProvider).forceStateEmit();
    } finally {
      _isPending = false;
    }
  }

  /// Updates session metadata for a preview without
  /// triggering playback or mode transition.
  ///
  /// Used by the EPG screen which manages its own
  /// [EpgPreviewService] for in-page video previews.
  void startPreview({
    required String streamUrl,
    bool isLive = false,
    String? channelName,
    String? channelLogoUrl,
    String? currentProgram,
    Map<String, String>? headers,
    List<Channel>? channelList,
    int channelIndex = 0,
    Duration? startPosition,
    String? mediaType,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    List<VodItem>? episodeList,
    String? posterUrl,
    String? seriesPosterUrl,
  }) {
    state = PlaybackSessionState(
      streamUrl: streamUrl,
      isLive: isLive,
      channelName: channelName,
      channelLogoUrl: channelLogoUrl,
      currentProgram: currentProgram,
      headers: headers,
      channelList: channelList,
      channelIndex: channelIndex,
      startPosition: startPosition,
      mediaType: mediaType,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeList: episodeList,
      posterUrl: posterUrl,
      seriesPosterUrl: seriesPosterUrl,
    );
  }

  /// Starts a full-screen playback session from a
  /// [PlaybackSessionParams] value object.
  ///
  /// Preferred over [startPlayback] for new call sites —
  /// keeps parameters grouped and typed.
  Future<void> startPlaybackWithParams(PlaybackSessionParams params) =>
      startPlayback(
        streamUrl: params.streamUrl,
        isLive: params.isLive,
        channelName: params.channelName,
        channelLogoUrl: params.channelLogoUrl,
        currentProgram: params.currentProgram,
        headers: params.headers,
        channelList: params.channelList,
        channelIndex: params.channelIndex,
        startPosition: params.startPosition,
        mediaType: params.mediaType,
        seriesId: params.seriesId,
        seasonNumber: params.seasonNumber,
        episodeNumber: params.episodeNumber,
        episodeList: params.episodeList,
        posterUrl: params.posterUrl,
        seriesPosterUrl: params.seriesPosterUrl,
      );

  /// Updates session metadata for a preview from a
  /// [PlaybackSessionParams] value object.
  ///
  /// Preferred over [startPreview] for new call sites.
  void startPreviewWithParams(PlaybackSessionParams params) => startPreview(
    streamUrl: params.streamUrl,
    isLive: params.isLive,
    channelName: params.channelName,
    channelLogoUrl: params.channelLogoUrl,
    currentProgram: params.currentProgram,
    headers: params.headers,
    channelList: params.channelList,
    channelIndex: params.channelIndex,
    startPosition: params.startPosition,
    mediaType: params.mediaType,
    seriesId: params.seriesId,
    seasonNumber: params.seasonNumber,
    episodeNumber: params.episodeNumber,
    episodeList: params.episodeList,
    posterUrl: params.posterUrl,
    seriesPosterUrl: params.seriesPosterUrl,
  );

  /// Updates the active channel index during zapping.
  void updateChannelIndex(int index) {
    state = state.copyWith(channelIndex: index);
  }

  /// Clears all session metadata and returns to idle.
  void clearSession() {
    state = const PlaybackSessionState();
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

/// Global playback session provider.
///
/// Holds all metadata for the current playback session and
/// exposes methods to start/stop/update it. Screens should
/// call [PlaybackSessionNotifier.startPlayback] instead of
/// calling [PlayerService.play] directly so that session
/// metadata is always in sync with actual playback.
final playbackSessionProvider =
    NotifierProvider<PlaybackSessionNotifier, PlaybackSessionState>(
      PlaybackSessionNotifier.new,
    );
