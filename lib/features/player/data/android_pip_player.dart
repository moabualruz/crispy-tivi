import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/crispy_player.dart';

/// [CrispyPlayer] adapter for Android Picture-in-Picture.
///
/// Communicates with the Kotlin `CrispyPipPlayerPlugin` via
/// `MethodChannel` and `EventChannel`. Unlike iOS PiP (which
/// requires a separate AVPlayer for AVPictureInPictureController),
/// Android PiP shrinks the activity window — the same player
/// engine can continue. This adapter wraps Media3 ExoPlayer for
/// scenarios where the primary media_kit player cannot provide
/// PiP-compatible rendering (e.g., SurfaceView requirements).
///
/// This player is only available on Android (API 26+) and should
/// be registered as a takeover player for [PlayerCapability.pip].
class AndroidPipPlayer implements CrispyPlayer {
  static const _channel = MethodChannel('com.crispytivi/pip_player_android');
  static const _eventChannel = EventChannel(
    'com.crispytivi/pip_player_android/events',
  );

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
  final _pipStateCtrl = StreamController<bool>.broadcast();

  StreamSubscription<dynamic>? _eventSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1.0;
  double _rate = 1.0;
  String? _currentUrl;
  bool _isPipActive = false;

  /// Position saved when entering PiP for restoration on exit.
  Duration savedPosition = Duration.zero;

  AndroidPipPlayer() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  /// Request Picture-in-Picture activation.
  ///
  /// Saves the current playback position before entering PiP
  /// so it can be restored on exit.
  Future<void> enterPiP() async {
    savedPosition = _position;
    _isPipActive = true;
    _pipStateCtrl.add(true);
    await _channel.invokeMethod('enterPiP');
  }

  /// Exit Picture-in-Picture and restore position.
  Future<void> exitPiP() async {
    await _channel.invokeMethod('exitPiP');
    _isPipActive = false;
    _pipStateCtrl.add(false);
    // Position is preserved — Android PiP doesn't change the
    // player engine, so _position stays accurate.
  }

  /// Whether PiP is currently active.
  bool get isPipActive => _isPipActive;

  /// Stream of PiP state changes.
  Stream<bool> get pipStateStream => _pipStateCtrl.stream;

  /// Simulate a position update (for testing).
  void simulatePositionUpdate(Duration pos) {
    _position = pos;
    _positionCtrl.add(pos);
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
    _position = startPosition;
    await _channel.invokeMethod('open', {
      'url': url,
      'headers': httpHeaders,
      'startPositionMs': startPosition.inMilliseconds,
    });
  }

  @override
  Future<void> play() async => _channel.invokeMethod('play');

  @override
  Future<void> pause() async => _channel.invokeMethod('pause');

  @override
  Future<void> playOrPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    _currentUrl = null;
    await _channel.invokeMethod('stop');
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    await _channel.invokeMethod('seek', {
      'positionMs': position.inMilliseconds,
    });
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _channel.invokeMethod('setVolume', {'volume': _volume});
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    await _channel.invokeMethod('setRate', {'rate': rate});
  }

  @override
  Future<void> setAudioTrack(int index) async {
    await _channel.invokeMethod('setAudioTrack', {'index': index});
  }

  @override
  Future<void> setSubtitleTrack(int index) async {
    await _channel.invokeMethod('setSubtitleTrack', {'index': index});
  }

  @override
  void setSecondarySubtitleTrack(int index) {
    // Media3 ExoPlayer doesn't support secondary subtitles.
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

  @override
  Stream<CrispyTrackList> get tracksStream => _tracksCtrl.stream;

  // ── Synchronous State ───────────────────────────────

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get isPlaying => _isPlaying;

  @override
  double get volume => _volume;

  @override
  double get rate => _rate;

  @override
  String? get currentUrl => _currentUrl;

  // ── Tracks ──────────────────────────────────────────

  @override
  List<CrispyAudioTrack> get audioTracks => const [];

  @override
  List<CrispySubtitleTrack> get subtitleTracks => const [];

  // ── Video Widget ────────────────────────────────────

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain}) {
    return AndroidView(
      viewType: 'crispy_pip_player_android',
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  // ── Properties (no-op) ──────────────────────────────

  @override
  void setProperty(String key, String value) {}

  @override
  String? getProperty(String key) => null;

  // ── Capabilities ────────────────────────────────────

  @override
  bool get supportsHdr => false;

  @override
  bool get supportsPiP => true;

  @override
  bool get supportsBackgroundAudio => true;

  @override
  String get engineName => 'media3_pip';

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
    await _eventSub?.cancel();
    _eventSub = null;
    await _channel.invokeMethod('dispose');
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
    await _pipStateCtrl.close();
  }

  // ── Event Handling ──────────────────────────────────

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    switch (type) {
      case 'position':
        _position = Duration(milliseconds: event['value'] as int);
        _positionCtrl.add(_position);
      case 'duration':
        _duration = Duration(milliseconds: event['value'] as int);
        _durationCtrl.add(_duration);
      case 'buffer':
        final bufferMs = Duration(milliseconds: event['value'] as int);
        _bufferCtrl.add(bufferMs);
      case 'playing':
        _isPlaying = event['value'] as bool;
        _playingCtrl.add(_isPlaying);
      case 'state':
        _handleStateChange(event['value'] as String);
      case 'error':
        _errorCtrl.add(event['value'] as String?);
      case 'completed':
        _completedCtrl.add(true);
      case 'buffering':
        _bufferingCtrl.add(event['value'] as bool);
      case 'pipStarted':
        _isPipActive = true;
        _pipStateCtrl.add(true);
      case 'pipStopped':
        _isPipActive = false;
        _pipStateCtrl.add(false);
    }
  }

  void _handleStateChange(String state) {
    switch (state) {
      case 'buffering':
        _bufferingCtrl.add(true);
      case 'ready':
        _bufferingCtrl.add(false);
      case 'completed':
        _completedCtrl.add(true);
    }
  }
}
