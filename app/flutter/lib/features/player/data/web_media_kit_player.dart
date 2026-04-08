import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../player/presentation/widgets/web_hls_video.dart';
import '../domain/crispy_player.dart';
import 'web_video_bridge.dart';

/// [CrispyPlayer] backed by [WebVideoBridge] + [WebHlsVideo].
///
/// Used on web where media_kit's [Player] is unavailable. The
/// HTML `<video>` element + hls.js handle playback; this adapter
/// maps the [WebVideoBridge] polling API to [CrispyPlayer] streams.
class WebMediaKitPlayer implements CrispyPlayer {
  WebMediaKitPlayer({WebVideoBridge? bridge, GlobalKey? videoKey})
    : _bridge = bridge ?? WebVideoBridge(),
      _videoKey = videoKey ?? GlobalKey(debugLabel: 'WebHlsVideo');

  final WebVideoBridge _bridge;
  final GlobalKey _videoKey;
  String? _currentUrl;

  // Stream controllers fed by WebVideoBridge polling.
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _bufferCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<String?>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _volumeCtrl = StreamController<double>.broadcast();
  final _rateCtrl = StreamController<double>.broadcast();
  final _tracksCtrl = StreamController<CrispyTrackList>.broadcast();

  // Latest state snapshot from polling.
  WebVideoState _lastState = const WebVideoState();
  bool _isAttached = false;

  /// Attaches to a video element by DOM ID and starts polling.
  void attach(String videoId) {
    _bridge.attach(videoId);
    _isAttached = true;
    _bridge.startPolling(_onPoll);
  }

  void _onPoll(WebVideoState state) {
    _lastState = state;
    _positionCtrl.add(state.position);
    _durationCtrl.add(state.duration);
    _bufferCtrl.add(state.buffered);
    _playingCtrl.add(state.playing);
    _volumeCtrl.add(state.volume);
    _rateCtrl.add(state.speed);

    if (state.errorMessage != null) {
      _errorCtrl.add(state.errorMessage);
    }

    // Buffering: readyState < 3 while not paused.
    _bufferingCtrl.add(state.readyState < 3 && !state.paused);

    // Completed: position ≈ duration when duration > 0.
    if (state.duration > Duration.zero &&
        state.position >= state.duration - const Duration(milliseconds: 500) &&
        !state.playing) {
      _completedCtrl.add(true);
    }

    // Emit tracks.
    _tracksCtrl.add(
      CrispyTrackList(
        audio:
            state.audioTracks
                .asMap()
                .entries
                .map(
                  (e) => CrispyAudioTrack(
                    index: e.key,
                    title: e.value['name'] ?? 'Track ${e.key + 1}',
                    language: e.value['lang'],
                  ),
                )
                .toList(),
        subtitle:
            state.subtitleTracks
                .asMap()
                .entries
                .map(
                  (e) => CrispySubtitleTrack(
                    index: e.key,
                    title: e.value['name'] ?? 'Track ${e.key + 1}',
                    language: e.value['lang'],
                  ),
                )
                .toList(),
      ),
    );
  }

  // ── Commands ────────────────────────────────────────

  @override
  Future<void> open(
    String url, {
    Map<String, String>? httpHeaders,
    Map<String, dynamic>? extras,
    Duration startPosition = Duration.zero,
  }) async {
    _currentUrl = url;
    // WebHlsVideo handles URL via widget rebuild — no bridge
    // call needed. The widget's onVideoIdReady callback will
    // trigger attach().
  }

  @override
  Future<void> play() async => _bridge.resume();

  @override
  Future<void> pause() async => _bridge.pause();

  @override
  Future<void> playOrPause() async => _bridge.playOrPause();

  @override
  Future<void> stop() async {
    _currentUrl = null;
    _bridge.stop();
  }

  @override
  Future<void> seek(Duration position) async =>
      _bridge.seek(position.inMilliseconds / 1000.0);

  @override
  Future<void> setVolume(double volume) async =>
      _bridge.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> setRate(double rate) async => _bridge.setSpeed(rate);

  @override
  Future<void> setAudioTrack(int index) async => _bridge.setAudioTrack(index);

  @override
  Future<void> setSubtitleTrack(int index) async =>
      _bridge.setSubtitleTrack(index);

  @override
  void setSecondarySubtitleTrack(int index) {
    // Web HTML5 video doesn't support secondary subtitles.
  }

  // ── Streams ─────────────────────────────────────────

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration> get durationStream => _durationCtrl.stream;

  @override
  Stream<Duration> get bufferStream => _bufferCtrl.stream;

  @override
  Stream<bool> get playingStream => _playingCtrl.stream;

  @override
  Stream<bool> get completedStream => _completedCtrl.stream;

  @override
  Stream<String?> get errorStream => _errorCtrl.stream;

  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;

  @override
  Stream<double> get volumeStream => _volumeCtrl.stream;

  @override
  Stream<double> get rateStream => _rateCtrl.stream;

  // ── Synchronous State ──────────────────────────────

  @override
  Duration get position => _lastState.position;

  @override
  Duration get duration => _lastState.duration;

  @override
  bool get isPlaying => _lastState.playing;

  @override
  double get volume => _lastState.volume;

  @override
  double get rate => _lastState.speed;

  @override
  String? get currentUrl => _currentUrl;

  // ── Tracks ──────────────────────────────────────────

  @override
  List<CrispyAudioTrack> get audioTracks =>
      _lastState.audioTracks
          .asMap()
          .entries
          .map(
            (e) => CrispyAudioTrack(
              index: e.key,
              title: e.value['name'] ?? 'Track ${e.key + 1}',
              language: e.value['lang'],
            ),
          )
          .toList();

  @override
  List<CrispySubtitleTrack> get subtitleTracks =>
      _lastState.subtitleTracks
          .asMap()
          .entries
          .map(
            (e) => CrispySubtitleTrack(
              index: e.key,
              title: e.value['name'] ?? 'Track ${e.key + 1}',
              language: e.value['lang'],
            ),
          )
          .toList();

  @override
  Stream<CrispyTrackList> get tracksStream => _tracksCtrl.stream;

  // ── Video Widget ────────────────────────────────────

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain}) {
    return WebHlsVideo(
      key: _videoKey,
      streamUrl: _currentUrl ?? '',
      onVideoIdReady: (videoId) {
        if (!_isAttached) attach(videoId);
      },
    );
  }

  // ── Properties (no-op on web) ───────────────────────

  @override
  void setProperty(String key, String value) {}

  @override
  String? getProperty(String key) => null;

  // ── Capabilities ────────────────────────────────────

  @override
  bool get supportsHdr => false;

  @override
  bool get supportsPiP => false;

  @override
  bool get supportsBackgroundAudio => false;

  @override
  Future<Uint8List?> screenshotRawBytes() async => null;

  @override
  String get engineName => 'web_video';

  @override
  List<CrispyAudioDevice> get audioDevices => const [];

  @override
  String? get currentAudioDeviceName => null;

  @override
  void setAudioDevice(String name) {}

  // ── Dispose ─────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _currentUrl = null;
    _bridge.stopPolling();
    _bridge.dispose();
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _bufferCtrl.close();
    await _playingCtrl.close();
    await _completedCtrl.close();
    await _errorCtrl.close();
    await _bufferingCtrl.close();
    await _volumeCtrl.close();
    await _rateCtrl.close();
    await _tracksCtrl.close();
  }
}
