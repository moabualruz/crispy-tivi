import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/crispy_player.dart';

/// [CrispyPlayer] backed by AVPlayer + AVPlayerViewController for
/// iOS Picture-in-Picture support.
///
/// Communicates with the Swift `CrispyPipPlayerPlugin` via
/// `MethodChannel` and `EventChannel`. The video widget uses
/// `UiKitView` to embed the `AVPlayerViewController` which enables
/// native PiP via `AVPictureInPictureController`.
///
/// This player is only available on iOS and should be registered
/// as a takeover player for [PlayerCapability.pip].
class IosPipPlayer implements CrispyPlayer {
  static const _channel = MethodChannel('com.crispytivi/pip_player');
  static const _eventChannel = EventChannel('com.crispytivi/pip_player/events');

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

  IosPipPlayer() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  /// Request Picture-in-Picture activation.
  ///
  /// Must be called AFTER [open] and playback has started.
  /// PiP will only activate if the device supports it.
  Future<void> enterPiP() async {
    await _channel.invokeMethod('enterPiP');
  }

  /// Exit Picture-in-Picture.
  Future<void> exitPiP() async {
    await _channel.invokeMethod('exitPiP');
  }

  /// Whether PiP is currently active.
  bool get isPipActive => _isPipActive;

  /// Stream of PiP state changes.
  Stream<bool> get pipStateStream => _pipStateCtrl.stream;

  // ── Commands ────────────────────────────────────────

  @override
  Future<void> open(
    String url, {
    Map<String, String>? httpHeaders,
    Map<String, dynamic>? extras,
    Duration startPosition = Duration.zero,
  }) async {
    _currentUrl = url;
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
    // AVPlayer track selection is more complex — deferred to
    // Phase 4 provider migration when OSD track picker is wired.
  }

  @override
  Future<void> setSubtitleTrack(int index) async {
    // AVPlayer subtitle track selection — deferred to Phase 4.
  }

  @override
  void setSecondarySubtitleTrack(int index) {
    // AVPlayer doesn't support secondary subtitles.
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

  // ── Synchronous State ──────────────────────────────

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
  List<CrispyAudioTrack> get audioTracks => [];

  @override
  List<CrispySubtitleTrack> get subtitleTracks => [];

  // ── Video Widget ────────────────────────────────────

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain}) {
    return UiKitView(
      viewType: 'crispy_pip_player',
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  // ── Properties (no-op for AVPlayer) ────────────────

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
  String get engineName => 'avplayer';

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
      case 'pipRestoreUI':
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
