import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/entities/gpu_info.dart';
import '../domain/entities/playback_state.dart' as app;
import '../domain/entities/stream_profile.dart';
import '../domain/entities/upscale_mode.dart';
import '../domain/entities/upscale_quality.dart';
import '../../../core/utils/stream_url_actions.dart';
import '../domain/crispy_player.dart';
import 'adaptive_buffer.dart';
import 'android_pip_player.dart';
import 'ios_pip_player.dart';
import 'media_kit_player.dart';
import 'os_media_session.dart';
import 'player_handoff_manager.dart';
import 'stream_proxy.dart';
import 'upscale_manager.dart';
import 'warm_failover_engine.dart';
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

/// Wraps [CrispyPlayer] with a clean domain API.
///
/// Exposes a [stateStream] of [app.PlaybackState]
/// snapshots. All playback commands go through this
/// service — feature code never touches the player
/// directly.
///
/// Behaviour is split across mixins (all in the same
/// library via `part` files):
/// - [PlayerSubscriptionsMixin] — player stream
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
  PlayerService({
    super.player,
    super.clock,
    super.bufferManager,
    super.warmFailover,
    super.mediaSession,
  }) {
    _handoffManager = PlayerHandoffManager(primaryPlayer: _player);

    // Register platform-specific PiP takeover players.
    // Use dart:io Platform checks (not defaultTargetPlatform) to avoid
    // instantiating native MethodChannel players during desktop tests
    // where defaultTargetPlatform defaults to TargetPlatform.android.
    if (!kIsWeb && Platform.isIOS) {
      _handoffManager.registerTakeover(PlayerCapability.pip, IosPipPlayer());
    } else if (!kIsWeb && Platform.isAndroid) {
      _handoffManager.registerTakeover(
        PlayerCapability.pip,
        AndroidPipPlayer(),
      );
    }

    // LNX-02: Impeller + external textures broken on Linux
    // until Flutter PR#181656 lands in stable. Linux defaults
    // to Skia (--no-enable-impeller), which is safe.
    assert(
      kIsWeb ||
          defaultTargetPlatform != TargetPlatform.linux ||
          true, // No runtime Impeller detection — see build docs.
      'Linux: ensure --no-enable-impeller is set (Impeller '
      'external textures broken until Flutter stable update)',
    );
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

    // Guard: skip re-opening when the same URL and source type are already
    // playing. Prevents spurious "Reconnecting..." flicker on tab-switch-back
    // and redundant network round-trips.
    if (normalizedUrl == _lastUrl &&
        isLive == _lastIsLive &&
        _state.status == app.PlaybackStatus.playing) {
      debugPrint('PlayerService: same URL already playing — skipping reopen');
      return;
    }

    // Stop-before-play invariant: ensure previous stream is fully torn down
    // before opening a new one. Prevents resource leaks during content
    // switching (live->VOD, channel zap, etc.).
    if (_lastUrl != null && normalizedUrl != _lastUrl) {
      await stop();
    }

    // Notify adaptive buffer manager of channel change
    // so in-memory health counters are reset for the new URL.
    if (isLive && _bufferManager != null) {
      unawaited(_bufferManager.onChannelChange(normalizedUrl));
    }

    // Reset warm failover state for the new channel.
    // Must await to ensure the warm player's mpv instance
    // is fully quiesced before opening the new stream —
    // fire-and-forget causes native crashes on rapid
    // channel switches.
    if (_warmFailover != null) {
      await _warmFailover.onChannelChange();
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

    // Activate OS media session with channel metadata.
    unawaited(
      _mediaSession.activate(
        title: currentProgram ?? channelName ?? 'CrispyTivi',
        artist: channelName,
        artUrl: channelLogoUrl,
      ),
    );

    // On web, WebVideoBridge handles playback via the
    // <video> element — skip media_kit Player.open().
    if (_webBridge != null) {
      debugPrint(
        'PlayerService: web bridge active, '
        'skipping media_kit open',
      );
      return;
    }

    // Reset proxy state for the new channel.
    _audioCheckTimer?.cancel();
    _proxyActive = false;
    _proxyRetriedUrls.clear();
    unawaited(_streamProxy.stop());

    await openMedia(url, isLive: isLive);

    // Schedule audio track detection watchdog — if no audio
    // tracks appear within 3s, retry through ffmpeg proxy.
    _scheduleAudioCheck(url);
  }

  /// Opens media with appropriate options for live
  /// vs VOD.
  @override
  Future<void> openMedia(String url, {bool isLive = false}) async {
    final effectiveUrl = normalizeStreamUrl(url);

    final extras = <String, dynamic>{};

    if (!kIsWeb) {
      if (isLive) {
        // mpv/libmpv options optimized for live MPEG-TS.
        extras['demuxer-lavf-o'] =
            'reconnect=1,reconnect_streamed=1,'
            'reconnect_delay_max=5';

        // Adaptive buffer: use persisted tier if available,
        // otherwise default to normal (120s readahead).
        if (_bufferManager != null) {
          final tier = await _bufferManager.getTierForUrl(effectiveUrl);
          extras.addAll(AdaptiveBufferManager.mpvOptionsForTier(tier));
          debugPrint(
            'PlayerService: adaptive buffer tier=${tier.name} '
            '(readahead=${tier.readaheadSecs}s)',
          );
        } else {
          extras['cache'] = 'yes';
          extras['cache-pause'] = 'no';
          extras['demuxer-readahead-secs'] = '120';
        }

        extras['untimed'] = '';
        // Reduce audio/video drift on live streams with variable
        // frame rates. For VOD the default 'audio' sync is better.
        extras['video-sync'] = 'display-resample';
      } else {
        // VOD: explicitly reset live-specific mpv options to
        // defaults. mpv carries options across open() calls —
        // without this, live reconnect/cache/untimed options
        // persist into VOD playback and cause native crashes
        // (e.g. reconnect loop on Jellyfin static endpoints).
        extras['demuxer-lavf-o'] = '';
        extras['cache'] = 'no';
        extras['cache-pause'] = 'yes';
        extras['demuxer-readahead-secs'] = '0';
        extras['untimed'] = 'no';
        extras['video-sync'] = 'audio';
      }
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

      if (_maxVolume > 100) {
        extras['volume-max'] = '$_maxVolume';
        debugPrint('PlayerService: volume-max=$_maxVolume');
      }

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

      // EBU R128 loudness normalization.
      if (_loudnessNormalization) {
        extras['af'] = 'loudnorm=I=-14:TP=-1:LRA=13';
        debugPrint('PlayerService: af=loudnorm (EBU R128)');
      }

      // Surround-to-stereo downmix.
      if (_stereoDownmix) {
        extras['audio-channels'] = 'stereo';
        extras['audio-normalize-downmix'] = 'yes';
        debugPrint('PlayerService: stereo downmix enabled');
      }
    }

    await _player.open(
      effectiveUrl,
      httpHeaders: _lastHeaders,
      extras: extras.isNotEmpty ? extras : null,
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

  /// Set volume (0.0 – maxVolume/100).
  ///
  /// When [maxVolume] is 100 (default), range is 0.0–1.0.
  /// When [maxVolume] is 200, range is 0.0–2.0, etc.
  Future<void> setVolume(double volume) async {
    final max = _maxVolume / 100.0;
    final clamped = volume.clamp(0.0, max);
    if (_webBridge != null) {
      // Web: cap at 1.0 (browser limitation).
      _webBridge!.setVolume(clamped.clamp(0.0, 1.0));
      _updateState(volume: clamped, isMuted: clamped <= 0);
      return;
    }
    await _player.setVolume(clamped);
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

    await _player.setAudioTrack(index);
    _updateState(selectedAudioTrackId: index);
  }

  /// Select a subtitle track by index, or -1 to
  /// disable subtitles.
  Future<void> setSubtitleTrack(int index) async {
    if (_webBridge != null) {
      _webBridge!.setSubtitleTrack(index);
      _updateState(selectedSubtitleTrackId: index);
      return;
    }

    await _player.setSubtitleTrack(index);
    _updateState(selectedSubtitleTrackId: index);
    // Clear secondary if primary is disabled or matches.
    final sec = _state.selectedSecondarySubtitleTrackId;
    if (index == -1 || index == sec) {
      clearSecondarySubtitleTrack();
    }
  }

  /// Select a secondary subtitle track by index.
  ///
  /// Uses mpv's `secondary-sid` property to display two
  /// subtitle tracks simultaneously. Pass -1 or call
  /// [clearSecondarySubtitleTrack] to disable.
  void setSecondarySubtitleTrack(int index) {
    if (kIsWeb || index == -1) {
      clearSecondarySubtitleTrack();
      return;
    }
    // Don't set secondary to same as primary.
    if (index == _state.selectedSubtitleTrackId) return;

    _player.setSecondarySubtitleTrack(index);
    _updateState(selectedSecondarySubtitleTrackId: index);
  }

  /// Clear the secondary subtitle track.
  void clearSecondarySubtitleTrack() {
    _player.setSecondarySubtitleTrack(-1);
    _updateState(clearSecondarySubtitle: true);
  }

  /// Sets the mpv audio filter string (`af`).
  ///
  /// Primarily used by the Equalizer feature. Composes with
  /// loudness normalization when both are active. No-op on web
  /// where mpv properties are unavailable.
  void setAudioFilter(String filterStr) {
    if (kIsWeb) return;
    final chain = _buildAudioFilterChain(eqFilter: filterStr);
    _player.setProperty('af', chain);
  }

  /// Builds the composite `af` filter chain from loudnorm +
  /// equalizer filters. Returns empty string when neither is
  /// active.
  String _buildAudioFilterChain({String eqFilter = ''}) {
    final parts = <String>[];
    if (_loudnessNormalization) {
      parts.add('loudnorm=I=-14:TP=-1:LRA=13');
    }
    if (eqFilter.isNotEmpty) {
      parts.add(eqFilter);
    }
    return parts.join(',');
  }

  /// Enables or disables deinterlacing via mpv.
  ///
  /// [mode] can be `'off'`, `'auto'`, or `'on'`. No-op on web.
  void setDeinterlace(String mode) {
    if (kIsWeb) return;
    // mpv deinterlace property accepts yes/no/auto.
    final value = switch (mode) {
      'on' => 'yes',
      'auto' => 'auto',
      _ => 'no',
    };
    _player.setProperty('deinterlace', value);
  }

  /// Force refresh — restarts the current stream.
  ///
  /// Clears the URL dedup guard so the same stream can be
  /// reopened with different player options (e.g. quality change).
  Future<void> refresh() async {
    if (_lastUrl == null) return;
    final url = _lastUrl!;
    final isLive = _lastIsLive;
    final name = _lastChannelName;
    final logo = _lastChannelLogoUrl;
    final prog = _lastCurrentProgram;
    final hdrs = _lastHeaders;
    _lastUrl = null; // Clear so play() bypasses the dedup guard.
    await play(
      url,
      isLive: isLive,
      channelName: name,
      channelLogoUrl: logo,
      currentProgram: prog,
      headers: hdrs,
    );
  }

  /// Stop playback and reset state.
  ///
  /// Dispose cascade order (guaranteed):
  /// 1. Cancel watchdog + retry/sleep timers
  /// 2. Reset warm failover state
  /// 3. Stop stream proxy
  /// 4. Deactivate media session
  /// 5. Stop CrispyPlayer (or web bridge)
  /// 6. Reset PlaybackState to idle
  /// 7. Emit idle state on stream
  ///
  /// Idempotent: safe to call multiple times. Each
  /// step is individually guarded so double-stop does not
  /// crash or double-dispose resources.
  @override
  Future<void> stop() async {
    // 1. Cancel watchdog + retry/sleep timers.
    stopWatchdog();
    _retryTimer?.cancel();
    _retryTimer = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;

    // 2. Reset warm failover state (not dispose — dispose is
    // only in PlayerService.dispose()). Prevents double-dispose
    // when stop() is followed by dispose().
    if (_warmFailover != null) {
      await _warmFailover.onChannelChange();
    }

    // 3. Stop stream proxy.
    _audioCheckTimer?.cancel();
    _proxyActive = false;
    unawaited(_streamProxy.stop());

    _lastUrl = null;
    _retryCount = 0;

    // 4. Deactivate media session.
    unawaited(_mediaSession.deactivate());

    // 5. Stop CrispyPlayer (or web bridge).
    if (_webBridge != null) {
      _webBridge!.stop();
    } else {
      await _player.stop();
    }

    // 6–7. Reset PlaybackState to idle and emit.
    _state = const app.PlaybackState();
    _stateController.add(_state);
  }

  /// Full disposal cascade (extends [stop]):
  /// 1. All stop() cleanup (timers, proxy, media session, player)
  /// 2. Close state stream controller
  /// 3. Cancel position flush timer
  /// 4. Dispose CrispyPlayer instance
  /// 5. Dispose handoff manager
  Future<void> dispose() async {
    stopWatchdog();
    _retryTimer?.cancel();
    _sleepTimer?.cancel();
    _positionFlushTimer?.cancel();
    _audioCheckTimer?.cancel();
    await _warmFailover?.dispose();
    await _streamProxy.stop();
    _webBridge?.dispose();
    _webBridge = null;
    await _syncWakelock(app.PlaybackStatus.idle);
    _bufferingDebounce?.cancel();
    await _mediaSession.dispose();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _stateController.close();
    await _handoffManager.disposeAll();
    await _player.dispose();
  }
}
