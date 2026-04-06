import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../data/stalker_session_service.dart';
import '../../data/stream_url_resolver.dart';
import '../../domain/entities/playback_session_params.dart';
import '../widgets/bookmark_overlay.dart';
import 'player_providers.dart';
import 'playback_session_state.dart';

export 'playback_session_state.dart';
export 'playback_session_preview.dart';

// ─────────────────────────────────────────────────────────────
//  PlaybackSessionNotifier
// ─────────────────────────────────────────────────────────────

/// Manages the active playback session.
///
/// Calling [startPlayback] both persists all session
/// metadata and triggers video playback via
/// [PlayerService] and a fullscreen mode transition.
///
/// Calling [startPreview] (in playback_session_preview.dart)
/// only updates the metadata — useful for EPG previews.
class PlaybackSessionNotifier extends Notifier<PlaybackSessionState> {
  @override
  PlaybackSessionState build() => const PlaybackSessionState();

  bool _isPending = false;
  int _requestId = 0;

  /// Starts a full-screen playback session.
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
    String? sourceId,
  }) async {
    final myRequestId = ++_requestId;

    if (_isPending) return;
    _isPending = true;
    try {
      String effectiveUrl = streamUrl;
      Map<String, String>? effectiveHeaders = headers;
      final isSynthetic = const [
        'plex',
        'emby',
        'jellyfin',
      ].contains(Uri.tryParse(streamUrl)?.scheme);
      try {
        final sources = ref.read(settingsNotifierProvider).value?.sources ?? [];
        final backend = ref.read(crispyBackendProvider);
        final resolver = StreamUrlResolver(sources, backend: backend);
        final stalkerStreamType = isLive ? 'itv' : 'vod';
        final resolved = await resolver.resolve(
          streamUrl,
          sourceId: sourceId,
          streamType: stalkerStreamType,
        );
        if (_requestId != myRequestId) return;
        if (resolved != null) {
          effectiveUrl = resolved.url;
          effectiveHeaders = {...?headers, ...?resolved.headers};
        }
      } catch (e) {
        debugPrint('StreamUrlResolver: failed to resolve $streamUrl: $e');
        if (isSynthetic) {
          debugPrint(
            'StreamUrlResolver: aborting — synthetic URL unresolvable',
          );
          return;
        }
      }

      if (_requestId != myRequestId) return;

      final stalkerSession = ref.read(stalkerSessionServiceProvider);
      if (sourceId != null) {
        final sources = ref.read(settingsNotifierProvider).value?.sources ?? [];
        final source = sources.where((s) => s.id == sourceId).firstOrNull;
        if (source != null && source.type == PlaylistSourceType.stalkerPortal) {
          stalkerSession.startKeepalive(
            source: source,
            streamType: isLive ? 'itv' : 'vod',
          );
        } else {
          stalkerSession.stopKeepalive();
        }
      } else {
        stalkerSession.stopKeepalive();
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
        sourceId: sourceId,
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

      if (_requestId != myRequestId) return;

      final savedSpeed = ref.read(lastPlaybackSpeedProvider);
      if (!isLive && savedSpeed != 1.0) {
        await ref.read(playerServiceProvider).setSpeed(savedSpeed);
      } else if (isLive) {
        await ref.read(playerServiceProvider).setSpeed(1.0);
      }

      if (_requestId != myRequestId) return;

      ref
          .read(playerModeProvider.notifier)
          .enterFullscreen(
            hostRoute: ref.read(playerModeProvider).currentRoute,
          );
      ref.read(playerServiceProvider).forceStateEmit();

      ref
          .read(bookmarkProvider.notifier)
          .loadForContent(effectiveUrl, isLive ? 'channel' : 'vod');
    } finally {
      _isPending = false;
    }
  }

  /// Starts a full-screen playback session from a
  /// [PlaybackSessionParams] value object.
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
        sourceId: params.sourceId,
      );

  /// Updates the active channel index during zapping.
  void updateChannelIndex(int index) {
    state = state.copyWith(channelIndex: index);
  }

  /// Clears all session metadata and returns to idle.
  void clearSession() {
    ref.read(stalkerSessionServiceProvider).stopKeepalive();
    state = const PlaybackSessionState();
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

/// Global playback session provider.
final playbackSessionProvider =
    NotifierProvider<PlaybackSessionNotifier, PlaybackSessionState>(
      PlaybackSessionNotifier.new,
    );
