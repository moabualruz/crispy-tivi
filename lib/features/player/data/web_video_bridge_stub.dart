/// Stub escapeJs for native platforms — never called, only here
/// so the conditional export compiles on all targets.
String escapeJs(String value) => value;

/// Stub [WebVideoBridge] for native platforms.
///
/// All methods are no-ops. This class is never used on
/// native because the caller guards with `kIsWeb`.
class WebVideoBridge {
  /// Attaches to a `<video>` element by its DOM ID.
  void attach(String videoId) {}

  /// Starts polling the video element for state updates.
  void startPolling(void Function(WebVideoState) onState) {}

  /// Stops polling.
  void stopPolling() {}

  /// Toggles play/pause on the video element.
  void playOrPause() {}

  /// Pauses the video element.
  void pause() {}

  /// Resumes the video element.
  void resume() {}

  /// Sets volume (0.0 – 1.0).
  void setVolume(double volume) {}

  /// Toggles mute on the video element.
  void toggleMute() {}

  /// Sets playback speed.
  void setSpeed(double speed) {}

  /// Seeks to a position in seconds.
  void seek(double positionSeconds) {}

  /// Stops playback.
  void stop() {}

  /// Changes the `<video>` CSS object-fit.
  void setObjectFit(String fit) {}

  /// Returns HLS.js audio tracks (web only).
  List<Map<String, String>> getAudioTracks() => [];

  /// Returns HLS.js subtitle tracks (web only).
  List<Map<String, String>> getSubtitleTracks() => [];

  /// Sets HLS.js audio track by index.
  void setAudioTrack(int index) {}

  /// Sets HLS.js subtitle track by index (-1 = off).
  void setSubtitleTrack(int index) {}

  /// Returns real-time stream statistics (web only).
  Map<String, String> getStreamStats() => {};

  /// Disposes resources.
  void dispose() {}
}

/// State snapshot from the web `<video>` element.
class WebVideoState {
  const WebVideoState({
    this.playing = false,
    this.paused = true,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.speed = 1.0,
    this.buffered = Duration.zero,
    this.muted = false,
    this.readyState = 0,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.errorMessage,
  });

  final bool playing;
  final bool paused;
  final Duration position;
  final Duration duration;
  final double volume;
  final double speed;
  final Duration buffered;
  final bool muted;

  /// HTML5 `readyState`:
  /// 0=HAVE_NOTHING, 1=HAVE_METADATA,
  /// 2=HAVE_CURRENT_DATA, 3=HAVE_FUTURE_DATA,
  /// 4=HAVE_ENOUGH_DATA.
  final int readyState;

  /// HLS.js audio tracks — each has 'id', 'name',
  /// 'lang' keys.
  final List<Map<String, String>> audioTracks;

  /// HLS.js subtitle tracks — each has 'id', 'name',
  /// 'lang' keys.
  final List<Map<String, String>> subtitleTracks;

  /// HLS.js fatal error message, or `null` if no error.
  final String? errorMessage;
}
