part of 'player_service.dart';

/// Stream info diagnostics and aspect ratio cycling.
///
/// Provides the [streamInfo] map for the OSD "Stream
/// Info" panel and [cycleAspectRatio] for toggling
/// video aspect ratios.
mixin PlayerStreamInfoMixin on PlayerServiceBase {
  /// Cycle to the next aspect ratio.
  ///
  /// Updates the label in [PlaybackState] and, on web,
  /// applies the corresponding CSS `object-fit` to the
  /// `<video>` element via [WebVideoBridge].
  void cycleAspectRatio() {
    final current = _state.aspectRatioLabel;
    final ratios = PlayerService.aspectRatios;
    final idx = ratios.indexOf(current);
    final next = ratios[(idx + 1) % ratios.length];
    debugPrint(
      'PlayerService: aspect ratio '
      '$current -> $next',
    );
    _updateState(aspectRatioLabel: next);

    // Apply CSS object-fit on web.
    _webBridge?.setObjectFit(PlayerService.cssObjectFitFromLabel(next));
  }

  /// Returns real-time stream info from the actual
  /// player backend.
  ///
  /// On web, reads from [WebVideoBridge.getStreamStats]
  /// which queries the HTML `<video>` element and
  /// hls.js. On native, reads directly from media_kit's
  /// live [Player.state].
  Map<String, String> get streamInfo {
    // Web path: get real stats from the bridge.
    if (_webBridge != null) {
      final webStats = _webBridge!.getStreamStats();
      return {
        'URL': _lastUrl ?? 'N/A',
        'Status': _state.status.name,
        ...webStats,
        'Audio Tracks': '${_state.audioTracks.length}',
        'Subtitle Tracks': '${_state.subtitleTracks.length}',
        'Speed': '${_state.speed}x',
        'Aspect Ratio': _state.aspectRatioLabel,
        'Stream Type': _lastIsLive ? 'LIVE' : 'VOD',
        'HW Decoder': _hwdecMode,
        ..._externalStreamInfo,
      };
    }

    // Native path: read from media_kit Player.state.
    final ps = _player.state;
    final w = ps.width ?? 0;
    final h = ps.height ?? 0;
    final buffer = ps.buffer;
    final video = ps.tracks.video;
    final audio = ps.tracks.audio;

    // Active video codec — filter sentinels.
    String videoCodec = 'N/A';
    final realVideo =
        video.where((t) => t.id != 'auto' && t.id != 'no').toList();
    if (realVideo.isNotEmpty) {
      final active = realVideo.first;
      videoCodec = active.title ?? active.id;
    }

    // Active audio codec.
    String audioCodec = 'N/A';
    final realAudio =
        audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    if (realAudio.isNotEmpty) {
      final active = realAudio.first;
      audioCodec = active.title ?? active.language ?? 'Unknown';
    }

    // Bitrate from media_kit.
    final bitrate = ps.audioBitrate;
    final bitrateStr =
        bitrate != null && bitrate > 0
            ? '${(bitrate / 1000).toStringAsFixed(0)}'
                ' kbps'
            : 'N/A';

    // Pixel format from videoParams.
    final vp = ps.videoParams;
    final pixFmt = vp.pixelformat ?? 'N/A';
    final hwPixFmt = vp.hwPixelformat;

    return {
      'URL': _lastUrl ?? 'N/A',
      'Status': _state.status.name,
      'Resolution': w > 0 ? '$w\u00D7$h' : 'N/A',
      'Pixel Format': pixFmt,
      if (hwPixFmt != null) 'HW Pixel Format': hwPixFmt,
      'Buffer': '${buffer.inSeconds}s',
      'Video Codec': videoCodec,
      'Audio Codec': audioCodec,
      'Audio Bitrate': bitrateStr,
      'Video Tracks': '${realVideo.length}',
      'Audio Tracks': '${_state.audioTracks.length}',
      'Subtitle Tracks': '${_state.subtitleTracks.length}',
      'Speed': '${_state.speed}x',
      'Aspect Ratio': _state.aspectRatioLabel,
      'Stream Type': _lastIsLive ? 'LIVE' : 'VOD',
      'HW Decoder': _hwdecMode,
      'Stream Profile': _streamProfile.label,
    };
  }
}
