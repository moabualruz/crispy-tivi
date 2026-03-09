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

  /// Returns normalized cache range segments for the
  /// seek bar's [BufferRangePainter].
  ///
  /// Tries to read multiple seekable ranges from mpv's
  /// `demuxer-cache-state` node property. Falls back to a
  /// single range derived from [PlaybackState.bufferProgress].
  List<(double, double)> getCacheRanges() {
    final durationMs = _state.duration.inMilliseconds;
    if (durationMs == 0) return [];

    // Try reading seekable-ranges from mpv (node sub-paths).
    final ranges = <(double, double)>[];
    for (var i = 0; i < 10; i++) {
      final startStr = _player.getProperty(
        'demuxer-cache-state/seekable-ranges/$i/start',
      );
      if (startStr == null) break;
      final endStr = _player.getProperty(
        'demuxer-cache-state/seekable-ranges/$i/end',
      );
      if (endStr == null) break;
      final start = double.tryParse(startStr);
      final end = double.tryParse(endStr);
      if (start != null && end != null) {
        final durationSec = durationMs / 1000.0;
        ranges.add((
          (start / durationSec).clamp(0.0, 1.0),
          (end / durationSec).clamp(0.0, 1.0),
        ));
      }
    }

    // Fallback: single contiguous range from buffer state.
    if (ranges.isEmpty) {
      final bp = _state.bufferProgress;
      if (bp > 0) ranges.add((0.0, bp));
    }

    return ranges;
  }

  /// Returns real-time stream info from the actual
  /// player backend.
  ///
  /// On web, reads from [WebVideoBridge.getStreamStats]
  /// which queries the HTML `<video>` element and
  /// hls.js. On native, reads diagnostics via
  /// [CrispyPlayer.getProperty].
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

    // Native path: read diagnostics via CrispyPlayer.
    final wRaw = _player.getProperty('width');
    final hRaw = _player.getProperty('height');
    final w = wRaw != null ? int.tryParse(wRaw) ?? 0 : 0;
    final h = hRaw != null ? int.tryParse(hRaw) ?? 0 : 0;

    final videoCodec = _player.getProperty('video-codec-name') ?? 'N/A';
    final audioCodec = _player.getProperty('audio-codec-name') ?? 'N/A';

    final bitrateRaw = _player.getProperty('audio-bitrate');
    final bitrate = bitrateRaw != null ? double.tryParse(bitrateRaw) : null;
    final bitrateStr =
        bitrate != null && bitrate > 0
            ? '${(bitrate / 1000).toStringAsFixed(0)} kbps'
            : 'N/A';

    final pixFmt = _player.getProperty('video-params/pixelformat') ?? 'N/A';
    final hwPixFmt = _player.getProperty('video-params/hw-pixelformat');

    final buffer = _state.bufferedPosition;

    // FPS: prefer estimated display fps, fall back to container fps.
    final fpsRaw =
        _player.getProperty('estimated-vf-fps') ??
        _player.getProperty('container-fps');
    final fps = fpsRaw != null ? double.tryParse(fpsRaw) : null;

    return {
      'URL': _lastUrl ?? 'N/A',
      'Status': _state.status.name,
      'Resolution': w > 0 ? '$w\u00D7$h' : 'N/A',
      'Pixel Format': pixFmt,
      if (hwPixFmt != null) 'HW Pixel Format': hwPixFmt,
      'Buffer': '${buffer.inSeconds}s',
      if (fps != null && fps > 0) 'FPS': fps.toStringAsFixed(1),
      'Video Codec': videoCodec,
      'Audio Codec': audioCodec,
      'Audio Bitrate': bitrateStr,
      'Audio Tracks': '${_state.audioTracks.length}',
      'Subtitle Tracks': '${_state.subtitleTracks.length}',
      'Speed': '${_state.speed}x',
      'Aspect Ratio': _state.aspectRatioLabel,
      'Stream Type': _lastIsLive ? 'LIVE' : 'VOD',
      'HW Decoder': _hwdecMode,
      'Stream Profile': _streamProfile.label,
      'Engine': _player.engineName,
    };
  }
}
