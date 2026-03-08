import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/data/web_video_bridge_web.dart' show escapeJs;
import 'package:web/web.dart' as web;

/// A web-only video widget that uses HLS.js for live stream
/// playback. Bypasses media_kit on web since Chrome cannot
/// play .m3u8 natively.
class WebHlsVideo extends StatefulWidget {
  const WebHlsVideo({
    required this.streamUrl,
    this.onError,
    this.onStatsUpdate,
    this.onVideoIdReady,
    this.startPosition,
    super.key,
  });

  final String streamUrl;
  final void Function(String message)? onError;
  final void Function(Map<String, String> stats)? onStatsUpdate;

  /// Called when the `<video>` element ID is available,
  /// allowing the parent to attach a [WebVideoBridge].
  final void Function(String videoId)? onVideoIdReady;

  /// Optional start position for the stream.
  final Duration? startPosition;

  @override
  State<WebHlsVideo> createState() => _WebHlsVideoState();
}

class _WebHlsVideoState extends State<WebHlsVideo> {
  late final String _viewType;
  static int _counter = 0;
  web.HTMLVideoElement? _videoElement;

  /// Normalize the stream URL and wrap through the CORS
  /// proxy when a backend is available (WEB-01).
  String get _hlsUrl {
    final normalized = normalizeStreamUrl(widget.streamUrl);
    final proxyBase = SmartImage.proxyBaseUrl;
    if (proxyBase != null && proxyBase.isNotEmpty) {
      return '$proxyBase/proxy?url=${Uri.encodeComponent(normalized)}';
    }
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _counter++;
    _viewType = 'web-hls-video-$_counter';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (
      int viewId, {
      Object? params,
    }) {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.style
        ..width = '100%'
        ..height = '100%'
        ..backgroundColor = 'black'
        ..position = 'relative'
        ..overflow = 'hidden'
        ..display = 'block';

      final video = web.document.createElement('video') as web.HTMLVideoElement;
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain'
        ..display = 'block'
        ..position = 'absolute'
        ..top = '0'
        ..left = '0';
      video.autoplay = true;
      video.controls = false;
      video.id = _viewType;
      // Required for inline playback on mobile browsers.
      video.setAttribute('playsinline', '');
      video.setAttribute('webkit-playsinline', '');
      _videoElement = video; // Capture for stats polling

      container.appendChild(video);

      // Attach HLS after the element is in the DOM.
      Timer(CrispyAnimation.fast, () {
        _attachHlsViaScript(_viewType, _hlsUrl, widget.startPosition);
        // Notify parent that the video ID is ready
        // for WebVideoBridge attachment.
        widget.onVideoIdReady?.call(_viewType);
      });

      return container;
    });
  }

  /// Finds the video element using multiple lookup strategies.
  /// Flutter web platform views may use shadow DOM, so
  /// `getElementById` alone is not reliable.
  static const String _findVideoJs = '''
    function _findVideo(id) {
      // 1. Standard lookup
      var v = document.getElementById(id);
      if (v) return v;
      // 2. querySelector fallback (shadow DOM)
      v = document.querySelector('video[id="' + id + '"]');
      if (v) return v;
      // 3. Search inside all shadow roots
      var hosts = document.querySelectorAll('flt-platform-view');
      for (var i = 0; i < hosts.length; i++) {
        var sr = hosts[i].shadowRoot;
        if (sr) {
          v = sr.querySelector('video[id="' + id + '"]');
          if (v) return v;
        }
      }
      // 4. Not found — return null (do NOT fall back
      // to any arbitrary video on the page).
      return null;
    }
  ''';

  /// Injects a <script> element to attach hls.js to the video.
  static void _attachHlsViaScript(
    String videoId,
    String url,
    Duration? startPosition,
  ) {
    final safeId = escapeJs(videoId);
    final safeUrl = escapeJs(url);
    final startPosSec =
        startPosition != null ? startPosition.inMilliseconds / 1000.0 : -1.0;

    final code = '''
(function() {
  $_findVideoJs

  var attempts = 0;
  function tryAttach() {
    attempts++;
    var video = _findVideo('$safeId');
    if (!video) {
      if (attempts < 20) {
        console.log('WebHlsVideo: #$safeId not found, retry ' + attempts);
        setTimeout(tryAttach, 500);
      } else {
        console.error('WebHlsVideo: #$safeId not found after 20 retries');
      }
      return;
    }
    console.log('WebHlsVideo: found video element (attempt ' + attempts + ')');

    var url = '$safeUrl';
    
    // 1. Check for native-compatible formats (MP4, MP3, etc.)
    // If it's NOT an HLS stream, skip hls.js.
    // Note: The Dart code already appends .m3u8 for known Xtream formats.
    var isHls = url.includes('.m3u8') || url.includes('.ts');
    
    if (!isHls) {
      console.log('WebHlsVideo: No .m3u8/.ts extension detected, using native playback for: ' + url);
      if (video._hls) {
         video._hls.destroy();
         video._hls = null;
      }
      if ($startPosSec >= 0) {
        video.currentTime = $startPosSec;
      }
      video.src = url;
      video.play().catch(function(e) {
        console.warn('WebHlsVideo: native autoplay blocked', e);
      });
      return;
    }

    // 2. Use hls.js for HLS streams if available
    if (typeof Hls !== 'undefined' && Hls.isSupported()) {
      if (video._hls) { video._hls.destroy(); }

      var hlsConfig = {
        enableWorker: true,
        lowLatencyMode: true,
        liveSyncDurationCount: 3,
        liveMaxLatencyDurationCount: 6,
        maxBufferLength: 10,
        maxMaxBufferLength: 30
      };
      
      if ($startPosSec >= 0) {
        hlsConfig.startPosition = $startPosSec;
      }

      var hls = new Hls(hlsConfig);
      video._hls = hls;
      hls.loadSource(url);
      hls.attachMedia(video);
      hls.on(Hls.Events.MANIFEST_PARSED, function(_, data) {
        console.log('WebHlsVideo: manifest parsed, levels: ' + (data.levels ? data.levels.length : 0));
        video.play().catch(function(e) {
          console.warn('WebHlsVideo: autoplay blocked', e);
          // Retry muted — browsers block unmuted autoplay.
          video.muted = true;
          video.play().catch(function(e2) {
            console.error('WebHlsVideo: muted autoplay also blocked', e2);
          });
        });
        // Log video dimensions once loaded.
        video.addEventListener('loadedmetadata', function() {
          console.log('WebHlsVideo: video dimensions ' + video.videoWidth + 'x' + video.videoHeight);
        }, { once: true });
      });
      hls.on(Hls.Events.ERROR, function(event, data) {
        if (data.fatal) {
          console.error('WebHlsVideo: fatal', data.type, data.details);
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              console.log('WebHlsVideo: network error, attempting recovery...');
              hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              console.log('WebHlsVideo: media error, attempting recovery...');
              hls.recoverMediaError();
              break;
            default:
              console.error('WebHlsVideo: unrecoverable fatal error');
              window._crispyHlsFatalError = data.type + ': ' + data.details;
              video.pause();
              break;
          }
        } else if (data.details === 'levelLoadError' || data.details === 'fragLoadError') {
           // Handle transient 403s or network blips by retrying
           console.warn('WebHlsVideo: transient load error', data.details);
           setTimeout(function() { hls.startLoad(); }, 1000);
        }
      });
      console.log('WebHlsVideo: hls.js attached for ' + url);
      return;
    }

    // 3. Native Fallback (Safari)
    console.warn('WebHlsVideo: hls.js not available, trying native');
    video.src = url;
    video.play().catch(function(e) {
      console.error('WebHlsVideo: native playback failed', e);
    });
  }
  tryAttach();
})();
''';
    _evalJs(code);
  }

  /// Destroy the hls.js instance for cleanup.
  static void _destroyHls(String videoId) {
    final safeId = escapeJs(videoId);
    _evalJs('''
(function() {
  $_findVideoJs
  var video = _findVideo('$safeId');
  if (video) {
    if (video._hls) {
      video._hls.destroy();
      video._hls = null;
    }
    video._hlsAttached = false;
  }
})();
''');
  }

  /// Removes the video element from the DOM on dispose
  /// to prevent stale elements from being found by
  /// fallback lookups.
  static void _removeVideoElement(String videoId) {
    final safeId = escapeJs(videoId);
    _evalJs('''
(function() {
  $_findVideoJs
  var video = _findVideo('$safeId');
  if (video) {
    video.pause();
    video.removeAttribute('src');
    video.load();
    if (video.parentNode) {
      video.parentNode.removeChild(video);
    }
  }
})();
''');
  }

  /// Execute arbitrary JS by injecting a <script> tag.
  static void _evalJs(String code) {
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.textContent = code;
    web.document.body?.appendChild(script);
    script.remove();
  }

  /// Updates the `<video>` element's object-fit CSS for
  /// aspect ratio cycling. Called from PlayerService.
  void setObjectFit(String fit) {
    _videoElement?.style.objectFit = fit;
  }

  @override
  void didUpdateWidget(WebHlsVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _attachHlsViaScript(_viewType, _hlsUrl, widget.startPosition);
    }
  }

  @override
  void dispose() {
    _destroyHls(_viewType);
    _removeVideoElement(_viewType);
    _videoElement = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
