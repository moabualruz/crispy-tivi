import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Escapes a string value for safe interpolation inside
/// JavaScript string literals (single-quoted, double-quoted,
/// or template literals).
///
/// Prevents XSS / arbitrary code execution when embedding
/// Dart values into JS code blocks passed to `_evalJs`.
String escapeJs(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('`', r'\`')
      .replaceAll(r'$', r'\$');
}

/// Bridge between Dart [PlayerService] and the HTML
/// `<video>` element used by [WebHlsVideo].
///
/// Uses JS interop to control playback and poll state.
class WebVideoBridge {
  String? _videoId;
  Timer? _pollTimer;
  void Function(WebVideoState)? _onState;
  double? _pendingSpeed;
  WebVideoState? _lastEmittedState;

  /// Cached reference to avoid repeated DOM traversals.
  web.HTMLVideoElement? _cachedVideo;
  web.EventListener? _boundEventListener;

  /// Attaches to a `<video>` element by its DOM ID.
  void attach(String videoId) {
    if (_cachedVideo != null && _boundEventListener != null) {
      _removeEventListeners(_cachedVideo!);
    }
    _videoId = videoId;
    _cachedVideo = null; // Reset cache for new element.
  }

  /// Starts polling the video element for state updates.
  ///
  /// Calls [onState] every 250ms with the current state
  /// of the `<video>` element.
  void startPolling(void Function(WebVideoState) onState) {
    _onState = onState;
    _pollTimer?.cancel();
    // Immediate first sync — don't wait 500ms.
    _poll();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _poll(),
    );
  }

  /// Stops polling.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastEmittedState = null;
    if (_cachedVideo != null && _boundEventListener != null) {
      _removeEventListeners(_cachedVideo!);
      _boundEventListener = null;
    }
  }

  void _addEventListeners(web.HTMLVideoElement v) {
    if (_boundEventListener != null) return;
    _boundEventListener = ((web.Event _) => _poll()).toJS;

    final events = [
      'play',
      'pause',
      'playing',
      'waiting',
      'stalled',
      'canplay',
      'error',
      'volumechange',
      'ratechange',
      'seeked',
    ];
    for (final e in events) {
      v.addEventListener(e, _boundEventListener);
    }
  }

  void _removeEventListeners(web.HTMLVideoElement v) {
    if (_boundEventListener == null) return;
    final events = [
      'play',
      'pause',
      'playing',
      'waiting',
      'stalled',
      'canplay',
      'error',
      'volumechange',
      'ratechange',
      'seeked',
    ];
    for (final e in events) {
      v.removeEventListener(e, _boundEventListener);
    }
  }

  /// Logs a warning to the browser console.
  static void _warn(String msg) {
    web.console.warn('WebVideoBridge: $msg'.toJS);
  }

  web.HTMLVideoElement? _findVideo() {
    // Return cached reference if still valid.
    if (_cachedVideo != null) return _cachedVideo;

    if (_videoId == null) {
      _warn('_findVideo: no videoId attached');
      return null;
    }
    // 1. Standard getElementById lookup.
    final el = web.document.getElementById(_videoId!);
    if (el != null) {
      _cachedVideo = el as web.HTMLVideoElement;
      _addEventListeners(_cachedVideo!);
      return _cachedVideo;
    }

    // 2. querySelector fallback.
    final q = web.document.querySelector('video[id="${_videoId!}"]');
    if (q != null) {
      _cachedVideo = q as web.HTMLVideoElement;
      _addEventListeners(_cachedVideo!);
      return _cachedVideo;
    }

    // 3. Search inside shadow roots of platform views.
    final hosts = web.document.querySelectorAll('flt-platform-view');
    for (var i = 0; i < hosts.length; i++) {
      final host = hosts.item(i)! as web.HTMLElement;
      final sr = host.shadowRoot;
      if (sr != null) {
        final v = sr.querySelector('video[id="${_videoId!}"]');
        if (v != null) {
          _cachedVideo = v as web.HTMLVideoElement;
          _addEventListeners(_cachedVideo!);
          return _cachedVideo;
        }
      }
    }

    _warn('<video> #$_videoId not found in DOM');
    return null;
  }

  void _poll() {
    final v = _findVideo();
    if (v == null || _onState == null) return;

    // Apply any queued speed change.
    if (_pendingSpeed != null) {
      v.playbackRate = _pendingSpeed!;
      _pendingSpeed = null;
    }

    var bufferedSec = 0.0;
    try {
      final buf = v.buffered;
      final cur = v.currentTime;
      for (var i = 0; i < buf.length; i++) {
        if (buf.start(i) <= cur && buf.end(i) >= cur) {
          bufferedSec = buf.end(i) - cur;
          break;
        }
      }
    } catch (e) {
      debugPrint(
        'web_video_bridge: '
        'video element time/duration read failed: $e',
      );
    }

    // Read track data from hls.js.
    final audioTracks = getAudioTracks();
    final subtitleTracks = getSubtitleTracks();

    // Read HLS.js fatal error from window global.
    String? hlsError;
    try {
      final errProp = globalContext.getProperty<JSAny?>(
        '_crispyHlsFatalError'.toJS,
      );
      if (errProp != null && !errProp.isUndefined && errProp.isA<JSString>()) {
        hlsError = (errProp as JSString).toDart;
        globalContext.setProperty('_crispyHlsFatalError'.toJS, null);
      }
    } catch (_) {}

    final newState = WebVideoState(
      playing: !v.paused && !v.ended,
      paused: v.paused,
      position: Duration(milliseconds: (v.currentTime * 1000).round()),
      duration: Duration(
        milliseconds: v.duration.isNaN ? 0 : (v.duration * 1000).round(),
      ),
      volume: v.volume,
      speed: v.playbackRate,
      buffered: Duration(milliseconds: (bufferedSec * 1000).round()),
      muted: v.muted,
      readyState: v.readyState,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
      errorMessage: hlsError,
    );
    if (newState != _lastEmittedState) {
      _lastEmittedState = newState;
      _onState!(newState);
    }
  }

  /// Toggles play/pause on the video element.
  void playOrPause() {
    final v = _findVideo();
    if (v == null) return;
    if (v.paused) {
      v.play().toDart.ignore();
    } else {
      v.pause();
    }
  }

  /// Pauses the video element.
  void pause() {
    _findVideo()?.pause();
  }

  /// Resumes the video element.
  void resume() {
    final v = _findVideo();
    if (v == null) return;
    v.play().toDart.ignore();
  }

  /// Sets volume (0.0 – 1.0).
  ///
  /// When [volume] is 0 the HTML element's `muted`
  /// property is also set so the OSD mute toggle
  /// works correctly on web.
  void setVolume(double volume) {
    final v = _findVideo();
    if (v == null) return;
    v.volume = volume.clamp(0.0, 1.0);
    if (volume <= 0) {
      v.muted = true;
    } else if (v.muted) {
      v.muted = false;
    }
  }

  /// Toggles mute on the video element.
  void toggleMute() {
    final v = _findVideo();
    if (v == null) return;
    v.muted = !v.muted;
  }

  /// Sets playback speed.
  ///
  /// If the `<video>` element is not yet mounted the
  /// value is queued and applied on the next poll cycle.
  void setSpeed(double speed) {
    final v = _findVideo();
    if (v == null) {
      _pendingSpeed = speed;
      return;
    }
    v.playbackRate = speed;
    _pendingSpeed = null;
  }

  /// Seeks to a position in seconds.
  void seek(double positionSeconds) {
    final v = _findVideo();
    if (v == null) return;
    v.currentTime = positionSeconds;
  }

  /// Stops playback.
  void stop() {
    final v = _findVideo();
    if (v == null) return;
    v.pause();
    v.currentTime = 0;
  }

  /// Changes the `<video>` element's CSS object-fit.
  ///
  /// Maps player aspect ratio labels to CSS values:
  /// - 'contain' (default), 'cover' (fill),
  ///   'fill' (stretch)
  void setObjectFit(String fit) {
    final v = _findVideo();
    if (v == null) return;
    v.style.objectFit = fit;
  }

  /// Returns HLS.js audio tracks via JS interop.
  ///
  /// Each entry has 'id', 'name', and 'lang' keys.
  /// Returns empty list if HLS.js is not attached.
  List<Map<String, String>> getAudioTracks() {
    final v = _findVideo();
    if (v == null) return [];

    final safeId = escapeJs(_videoId!);
    _evalJs('''
(function() {
  var v = document.getElementById('$safeId')
       || document.querySelector('video');
  if (!v || !v._hls) {
    window._hlsAudioTracks = '[]';
    return;
  }
  var tracks = v._hls.audioTracks || [];
  window._hlsAudioTracks = JSON.stringify(
    tracks.map(function(t, i) {
      return {
        id: '' + i,
        name: t.name || ('Track ' + (i+1)),
        lang: t.lang || '',
      };
    })
  );
})();
''');

    return _readJsonListFromWindow('_hlsAudioTracks');
  }

  /// Returns HLS.js subtitle tracks via JS interop.
  ///
  /// Each entry has 'id', 'name', and 'lang' keys.
  /// Returns empty list if HLS.js is not attached or
  /// the stream has no subtitles.
  List<Map<String, String>> getSubtitleTracks() {
    final v = _findVideo();
    if (v == null) return [];

    final safeId2 = escapeJs(_videoId!);
    _evalJs('''
(function() {
  var v = document.getElementById('$safeId2')
       || document.querySelector('video');
  if (!v || !v._hls) {
    window._hlsSubtitleTracks = '[]';
    return;
  }
  var tracks = v._hls.subtitleTracks || [];
  window._hlsSubtitleTracks = JSON.stringify(
    tracks.map(function(t, i) {
      return {
        id: '' + i,
        name: t.name || ('Subtitle ' + (i+1)),
        lang: t.lang || '',
      };
    })
  );
})();
''');

    return _readJsonListFromWindow('_hlsSubtitleTracks');
  }

  /// Sets the HLS.js audio track by index.
  void setAudioTrack(int index) {
    final safeId = escapeJs(_videoId!);
    _evalJs('''
(function() {
  var v = document.getElementById('$safeId')
       || document.querySelector('video');
  if (v && v._hls) { v._hls.audioTrack = $index; }
})();
''');
  }

  /// Sets the HLS.js subtitle track by index.
  /// Use -1 to disable subtitles.
  void setSubtitleTrack(int index) {
    final safeId = escapeJs(_videoId!);
    _evalJs('''
(function() {
  var v = document.getElementById('$safeId')
       || document.querySelector('video');
  if (v && v._hls) {
    v._hls.subtitleTrack = $index;
  }
})();
''');
  }

  /// Reads a JSON array string from a `window`
  /// property set by [_evalJs] and decodes it.
  static List<Map<String, String>> _readJsonListFromWindow(String prop) {
    try {
      final raw = globalContext.getProperty<JSAny?>(prop.toJS);
      if (raw == null || raw.isUndefined) return [];
      final json = (raw as JSString).toDart;
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      debugPrint(
        'web_video_bridge: '
        'audio track extraction failed: $e',
      );
      return [];
    }
  }

  /// Execute arbitrary JS via script tag injection.
  static void _evalJs(String code) {
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.textContent = code;
    web.document.body?.appendChild(script);
    script.remove();
  }

  /// Returns real-time stream statistics from the
  /// HTML `<video>` element and hls.js instance.
  ///
  /// Reads `videoWidth`, `videoHeight`,
  /// `getVideoPlaybackQuality()`, hls.js
  /// `bandwidthEstimate`, and active level codec info.
  Map<String, String> getStreamStats() {
    final v = _findVideo();
    if (v == null) return {};

    final stats = <String, String>{};

    // Resolution from the video element itself.
    final w = v.videoWidth;
    final h = v.videoHeight;
    if (w > 0) stats['Resolution'] = '$w\u00D7$h';

    // Buffer ahead (seconds).
    try {
      final buf = v.buffered;
      final cur = v.currentTime;
      for (var i = 0; i < buf.length; i++) {
        if (buf.start(i) <= cur && buf.end(i) >= cur) {
          final ahead = (buf.end(i) - cur).toInt();
          stats['Buffer'] = '${ahead}s';
          break;
        }
      }
    } catch (e) {
      debugPrint(
        'web_video_bridge: '
        'bandwidth stats read failed: $e',
      );
    }

    // Dropped frames.
    try {
      final q = v.getVideoPlaybackQuality();
      stats['Dropped Frames'] = '${q.droppedVideoFrames}/${q.totalVideoFrames}';
    } catch (e) {
      debugPrint(
        'web_video_bridge: '
        'dropped frames stats read failed: $e',
      );
    }

    // hls.js-specific stats via JS interop.
    final safeId = escapeJs(_videoId!);
    _evalJs('''
(function() {
  var v = document.getElementById('$safeId')
       || document.querySelector('video');
  if (!v || !v._hls) {
    window._crispyHlsStats = '{}';
    return;
  }
  var hls = v._hls;
  var s = {};

  // Bandwidth estimate (bits/s -> Mbps).
  if (hls.bandwidthEstimate) {
    s.bitrate = (hls.bandwidthEstimate / 1000000)
      .toFixed(2) + ' Mbps';
  }

  // Current level codec info.
  var lvl = hls.levels && hls.levels[hls.currentLevel];
  if (lvl) {
    if (lvl.videoCodec) s.videoCodec = lvl.videoCodec;
    if (lvl.audioCodec) s.audioCodec = lvl.audioCodec;
    if (lvl.width && lvl.height) {
      s.hlsResolution = lvl.width + 'x' + lvl.height;
    }
    if (lvl.bitrate) {
      s.levelBitrate = (lvl.bitrate / 1000000)
        .toFixed(2) + ' Mbps';
    }
  }

  // Latency for live.
  if (hls.latency !== undefined && hls.latency > 0) {
    s.latency = hls.latency.toFixed(1) + 's';
  }

  window._crispyHlsStats = JSON.stringify(s);
})();
''');

    try {
      final raw = globalContext.getProperty<JSAny?>('_crispyHlsStats'.toJS);
      if (raw != null && !raw.isUndefined) {
        final json = (raw as JSString).toDart;
        final map = jsonDecode(json) as Map<String, dynamic>;
        if (map.containsKey('bitrate')) {
          stats['Bitrate'] = map['bitrate'] as String;
        }
        if (map.containsKey('videoCodec')) {
          stats['Video Codec'] = map['videoCodec'] as String;
        }
        if (map.containsKey('audioCodec')) {
          stats['Audio Codec'] = map['audioCodec'] as String;
        }
        if (map.containsKey('levelBitrate')) {
          stats['Level Bitrate'] = map['levelBitrate'] as String;
        }
        if (map.containsKey('latency')) {
          stats['Latency'] = map['latency'] as String;
        }
      }
    } catch (e) {
      debugPrint(
        'web_video_bridge: '
        'hls.js stats extraction failed: $e',
      );
    }

    return stats;
  }

  /// Disposes resources.
  void dispose() {
    stopPolling();
    _videoId = null;
    _onState = null;
    _cachedVideo = null;
    _lastEmittedState = null;
  }
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebVideoState &&
          playing == other.playing &&
          paused == other.paused &&
          position == other.position &&
          duration == other.duration &&
          volume == other.volume &&
          speed == other.speed &&
          buffered == other.buffered &&
          muted == other.muted &&
          readyState == other.readyState &&
          listEquals(audioTracks, other.audioTracks) &&
          listEquals(subtitleTracks, other.subtitleTracks) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    playing,
    paused,
    position,
    duration,
    volume,
    speed,
    buffered,
    muted,
    readyState,
    Object.hashAll(audioTracks),
    Object.hashAll(subtitleTracks),
    errorMessage,
  );
}
