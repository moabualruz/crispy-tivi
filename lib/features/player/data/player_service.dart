import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/entities/gpu_info.dart';
import '../domain/entities/playback_state.dart' as app;
import '../domain/entities/stream_profile.dart';
import '../domain/entities/upscale_mode.dart';
import '../domain/entities/upscale_quality.dart';
import '../../../core/utils/stream_url_actions.dart';
import 'upscale_manager.dart';
import 'web_upscale_bridge.dart';
import 'web_video_bridge.dart';

part 'player_service_base.dart';
part 'player_subscriptions_mixin.dart';
part 'player_web_bridge_mixin.dart';
part 'player_watchdog_mixin.dart';
part 'player_sleep_timer_mixin.dart';
part 'player_stream_info_mixin.dart';
part 'player_audio_config_mixin.dart';
part 'player_upscale_mixin.dart';

/// Wraps [media_kit]'s [Player] with a clean domain API.
///
/// Exposes a [stateStream] of [app.PlaybackState]
/// snapshots. All playback commands go through this
/// service — feature code never touches the raw [Player]
/// directly.
///
/// Behaviour is split across mixins (all in the same
/// library via `part` files):
/// - [PlayerSubscriptionsMixin] — media_kit stream
///   subscriptions
/// - [PlayerWebBridgeMixin] — web `<video>` bridge
/// - [PlayerWatchdogMixin] — UI heartbeat watchdog
/// - [PlayerSleepTimerMixin] — sleep timer
/// - [PlayerStreamInfoMixin] — stream diagnostics
/// - [PlayerAudioConfigMixin] — audio/decoder config
class PlayerService extends PlayerServiceBase
    with
        PlayerSubscriptionsMixin,
        PlayerWebBridgeMixin,
        PlayerWatchdogMixin,
        PlayerSleepTimerMixin,
        PlayerStreamInfoMixin,
        PlayerAudioConfigMixin,
        PlayerUpscaleMixin {
  PlayerService({super.player, super.clock}) {
    initSubscriptions();
  }

  /// Aspect ratio options for cycling.
  static const aspectRatios = ['Original', '16:9', '4:3', 'Fill', 'Fit'];

  /// Maps an aspect ratio label to a CSS `object-fit`
  /// value for the web `<video>` element.
  static String cssObjectFitFromLabel(String label) {
    switch (label) {
      case 'Fill':
        return 'cover';
      case 'Fit':
        return 'fill';
      case 'Original':
      case '16:9':
      case '4:3':
      default:
        return 'contain';
    }
  }

  // ── Public API ───────────────────────────────────────

  /// Opens and plays a stream URL.
  ///
  /// Set [isLive] to `true` for live IPTV streams —
  /// this enables reconnection logic and passes
  /// optimized mpv options.
  Future<void> play(
    String url, {
    bool isLive = false,
    String? channelName,
    String? channelLogoUrl,
    String? currentProgram,
    Map<String, String>? headers,
  }) async {
    // Cancel any pending retry timer from the previous stream before
    // overwriting _lastUrl. Without this, a delayed timer fires for the
    // *new* URL and opens the stream a second time, causing the
    // "Reconnecting…" OSD on intentional channel switches.
    _retryTimer?.cancel();
    _retryTimer = null;
    // Discard any buffering-debounce that belongs to the previous stream.
    _bufferingDebounce?.cancel();
    _bufferingDebounce = null;

    final normalizedUrl = normalizeStreamUrl(url);

    // Detect VOD → Live transition for logging. player.open() handles
    // the transition in-place — no explicit stop() needed.
    final wasPlayingVod =
        _webBridge == null && _lastUrl != null && !_lastIsLive && isLive;

    // Guard: skip re-opening when the same URL and source type are already
    // playing. Prevents spurious "Reconnecting…" flicker on tab-switch-back
    // and redundant network round-trips (FIX-11: URL guard).
    if (normalizedUrl == _lastUrl &&
        isLive == _lastIsLive &&
        _state.status == app.PlaybackStatus.playing) {
      debugPrint('PlayerService: same URL already playing — skipping reopen');
      return;
    }
    // Store for reconnection.
    _lastUrl = normalizedUrl;
    _lastIsLive = isLive;
    _lastChannelName = channelName;
    _lastChannelLogoUrl = channelLogoUrl;
    _lastCurrentProgram = currentProgram;
    _lastHeaders = headers;
    _retryCount = 0;

    debugPrint(
      'PlayerService: play '
      '${isLive ? "[LIVE]" : "[VOD]"} $url',
    );

    // Start the heartbeat watchdog so zombie audio
    // is detected.
    startWatchdog();

    _state = _state.copyWith(
      status: app.PlaybackStatus.buffering,
      isLive: isLive,
      channelName: channelName,
      channelLogoUrl: channelLogoUrl,
      currentProgram: currentProgram,
      speed: 1.0,
      clearError: true,
      retryCount: 0,
    );
    _stateController.add(_state);

    // On web, WebVideoBridge handles playback via the
    // <video> element — skip media_kit Player.open().
    if (_webBridge != null) {
      debugPrint(
        'PlayerService: web bridge active, '
        'skipping media_kit open',
      );
      return;
    }

    // VOD → Live: player.open() replaces the current media in-place,
    // including codec/demuxer reset. No explicit stop() is needed — it
    // would create a timing gap where mpv is mid-teardown when open()
    // fires, causing the first connection attempt to fail.
    if (wasPlayingVod) {
      debugPrint('PlayerService: VOD→Live transition — opening in-place');
    }

    await openMedia(url, isLive: isLive);
  }

  /// Opens media with appropriate options for live
  /// vs VOD.
  @override
  Future<void> openMedia(String url, {bool isLive = false}) async {
    final effectiveUrl = normalizeStreamUrl(url);

    final extras = <String, dynamic>{};

    if (isLive && !kIsWeb) {
      // mpv/libmpv options optimized for live MPEG-TS.
      extras['demuxer-lavf-o'] =
          'reconnect=1,reconnect_streamed=1,'
          'reconnect_delay_max=5';
      extras['cache'] = 'no';
      extras['demuxer-readahead-secs'] = '5';
      extras['untimed'] = '';
    }

    // Apply stream profile / audio / hwdec.
    if (!kIsWeb) {
      final hlsBitrate = _streamProfile.mpvHlsBitrate;
      if (hlsBitrate != null) {
        extras['hls-bitrate'] = hlsBitrate;
        debugPrint(
          'PlayerService: applying stream profile '
          '${_streamProfile.label} '
          '(hls-bitrate=$hlsBitrate)',
        );
      }

      extras['hwdec'] = _hwdecMode;
      debugPrint('PlayerService: hwdec=$_hwdecMode');

      if (_audioOutput != 'auto') {
        extras['ao'] = _audioOutput;
        debugPrint('PlayerService: ao=$_audioOutput');
      }

      if (_audioPassthroughEnabled && _audioPassthroughCodecs.isNotEmpty) {
        extras['audio-spdif'] = _audioPassthroughCodecs.join(',');
        debugPrint(
          'PlayerService: audio-spdif='
          '${_audioPassthroughCodecs.join(",")}',
        );
      }
    }

    await _player.open(
      Media(
        effectiveUrl,
        httpHeaders: _lastHeaders,
        extras: extras.isNotEmpty ? extras : null,
      ),
    );
  }

  /// Manually retry the last stream. Resets retry
  /// count.
  Future<void> retry() async {
    if (_lastUrl == null) return;
    debugPrint('PlayerService: manual retry for $_lastUrl');
    await play(
      _lastUrl!,
      isLive: _lastIsLive,
      channelName: _lastChannelName,
      channelLogoUrl: _lastChannelLogoUrl,
      currentProgram: _lastCurrentProgram,
      headers: _lastHeaders,
    );
  }

  /// Toggle play/pause.
  Future<void> playOrPause() async {
    if (_webBridge != null) {
      _webBridge!.playOrPause();
      return;
    }
    await _player.playOrPause();
  }

  /// Pause playback.
  @override
  Future<void> pause() async {
    if (_webBridge != null) {
      _webBridge!.pause();
      return;
    }
    await _player.pause();
  }

  /// Resume playback.
  @override
  Future<void> resume() async {
    if (_webBridge != null) {
      _webBridge!.resume();
      return;
    }
    await _player.play();
  }

  /// Seek to a position.
  Future<void> seek(Duration position) async {
    if (_webBridge != null) {
      _webBridge!.seek(position.inMilliseconds / 1000.0);
      return;
    }
    await _player.seek(position);
  }

  /// Set volume (0.0 – 1.0).
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if (_webBridge != null) {
      _webBridge!.setVolume(clamped);
      // Optimistic update so OSD reflects the change
      // instantly instead of waiting for the 250 ms
      // poll.
      _updateState(volume: clamped, isMuted: clamped <= 0);
      return;
    }
    await _player.setVolume(clamped * 100.0);
  }

  /// Toggle mute.
  ///
  /// On web, toggles the HTML `<video>` element's
  /// `muted` property. On native, toggles between
  /// current volume and 0.
  void toggleMute() {
    if (_webBridge != null) {
      _webBridge!.toggleMute();
      _updateState(isMuted: !_state.isMuted);
      return;
    }
    // Native: toggle via volume.
    if (_state.volume > 0) {
      _lastVolumeBeforeMute = _state.volume;
      setVolume(0);
    } else {
      setVolume(_lastVolumeBeforeMute);
    }
  }

  /// Set playback speed.
  ///
  /// No-op for live streams. [speed] is clamped to
  /// `[0.25, 4.0]`.
  Future<void> setSpeed(double speed) async {
    if (_state.isLive) return;
    final clamped = speed.clamp(0.25, 4.0);
    if (_webBridge != null) {
      _webBridge!.setSpeed(clamped);
      return;
    }
    await _player.setRate(clamped);
  }

  /// Select an audio track by index.
  ///
  /// On web, delegates to [WebVideoBridge]. On native,
  /// maps the index to a real media_kit [AudioTrack],
  /// filtering out sentinel entries.
  Future<void> setAudioTrack(int index) async {
    if (_webBridge != null) {
      _webBridge!.setAudioTrack(index);
      _updateState(selectedAudioTrackId: index);
      return;
    }

    final realTracks =
        _player.state.tracks.audio
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
    if (index >= 0 && index < realTracks.length) {
      await _player.setAudioTrack(realTracks[index]);
      _updateState(selectedAudioTrackId: index);
    }
  }

  /// Select a subtitle track by index, or -1 to
  /// disable subtitles.
  Future<void> setSubtitleTrack(int index) async {
    if (index < 0) {
      if (_webBridge != null) {
        _webBridge!.setSubtitleTrack(-1);
      } else {
        await _player.setSubtitleTrack(SubtitleTrack.no());
      }
      _updateState(selectedSubtitleTrackId: -1);
      return;
    }

    if (_webBridge != null) {
      _webBridge!.setSubtitleTrack(index);
      _updateState(selectedSubtitleTrackId: index);
      return;
    }

    final realTracks =
        _player.state.tracks.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
    if (index >= 0 && index < realTracks.length) {
      await _player.setSubtitleTrack(realTracks[index]);
      _updateState(selectedSubtitleTrackId: index);
    }
  }

  /// Sets the mpv audio filter string (`af`).
  ///
  /// Primarily used by the Equalizer feature. No-op on web where
  /// mpv properties are unavailable.
  void setAudioFilter(String filterStr) {
    if (kIsWeb) return;
    try {
      (_player.platform as dynamic).setProperty('af', filterStr);
    } catch (e) {
      debugPrint('[PlayerService] Failed to set audio filter: $e');
    }
  }

  /// Enables or disables deinterlacing via mpv.
  ///
  /// [mode] can be 'off' or 'auto'. No-op on web.
  void setDeinterlace(String mode) {
    if (kIsWeb) return;
    try {
      final value =
          mode == 'auto' ? 'yes' : 'no'; // mpv deinterlace accepts yes/no/auto
      (_player.platform as dynamic).setProperty('deinterlace', value);
    } catch (e) {
      debugPrint('[PlayerService] Failed to set deinterlace property: $e');
    }
  }

  /// Force refresh — restarts the current stream.
  Future<void> refresh() async {
    await retry();
  }

  /// Stop playback and reset state.
  @override
  Future<void> stop() async {
    stopWatchdog();
    _retryTimer?.cancel();
    _retryTimer = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;

    _lastUrl = null;
    _retryCount = 0;

    if (_webBridge != null) {
      _webBridge!.stop();
    } else {
      await _player.stop();
    }
    _state = const app.PlaybackState();
    _stateController.add(_state);
  }

  /// Set fullscreen state manually (for tracking UI
  /// state).
  void setFullscreen(bool value) {
    _updateState(isFullscreen: value);
  }

  /// Dispose the player and clean up subscriptions.
  Future<void> dispose() async {
    stopWatchdog();
    _retryTimer?.cancel();
    _sleepTimer?.cancel();
    _positionFlushTimer?.cancel();
    _webBridge?.dispose();
    _webBridge = null;
    await _syncWakelock(app.PlaybackStatus.idle);
    _bufferingDebounce?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _stateController.close();
    _videoController = null;
    await _player.dispose();
  }
}
