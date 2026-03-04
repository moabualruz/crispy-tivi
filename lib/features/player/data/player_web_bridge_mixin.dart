part of 'player_service.dart';

/// Web `<video>` element bridge integration.
///
/// Handles attaching/detaching the [WebVideoBridge],
/// polling for state, and converting web track data
/// to domain [AudioTrack]/[SubtitleTrack] models.
mixin PlayerWebBridgeMixin on PlayerServiceBase {
  /// Attaches a web `<video>` element bridge for web
  /// playback. On native platforms this is never called.
  void attachWebVideo(String videoId) {
    _webBridge?.dispose();
    _webBridge = WebVideoBridge()..attach(videoId);
    _webBridge!.startPolling(_onWebVideoState);
    debugPrint('PlayerService: attached web video #$videoId');
  }

  /// Detaches the web video bridge.
  void detachWebVideo() {
    _webBridge?.dispose();
    _webBridge = null;
  }

  /// Called by [WebVideoBridge] polling with fresh state
  /// from the HTML `<video>` element.
  void _onWebVideoState(WebVideoState ws) {
    // Forward HLS.js fatal errors to the player state.
    if (ws.errorMessage != null) {
      _updateState(
        status: app.PlaybackStatus.error,
        errorMessage: ws.errorMessage,
      );
      return;
    }

    // Convert web track maps to domain models.
    final audioTracks =
        ws.audioTracks
            .asMap()
            .entries
            .map(
              (e) => app.AudioTrack(
                id: e.key,
                title: e.value['name'] ?? 'Track ${e.key + 1}',
                language: e.value['lang'],
              ),
            )
            .toList();

    final subtitleTracks =
        ws.subtitleTracks
            .asMap()
            .entries
            .map(
              (e) => app.SubtitleTrack(
                id: e.key,
                title: e.value['name'] ?? 'Subtitle ${e.key + 1}',
                language: e.value['lang'],
              ),
            )
            .toList();

    // Determine status from HTML5 readyState + play
    // state. readyState < 3 (HAVE_FUTURE_DATA) means
    // the video doesn't have enough data — show
    // buffering regardless of the paused attribute.
    final app.PlaybackStatus webStatus;
    if (ws.readyState < 3) {
      webStatus = app.PlaybackStatus.buffering;
    } else if (ws.playing) {
      webStatus = app.PlaybackStatus.playing;
    } else if (ws.paused) {
      webStatus = app.PlaybackStatus.paused;
    } else {
      webStatus = app.PlaybackStatus.buffering;
    }

    _updateState(
      status: webStatus,
      position: ws.position,
      duration: ws.duration,
      volume: ws.volume,
      isMuted: ws.muted,
      speed: ws.speed,
      bufferedPosition: ws.buffered,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
    );
  }

  /// Updates stream info from external sources
  /// (e.g. WebHlsVideo).
  void updateExternalStreamInfo(Map<String, String> info) {
    _externalStreamInfo = info;
    // Trigger update to refresh UI consumers of
    // streamInfo.
    _stateController.add(_state);
  }
}
