import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../domain/crispy_player.dart';

/// [CrispyPlayer] adapter for desktop mini-window PiP mode.
///
/// Unlike iOS/Android PiP (which use platform APIs), desktop PiP
/// is implemented by resizing the window to a small always-on-top
/// 16:9 frame using `window_manager`. The video continues in the
/// same media_kit player — no engine swap needed.
///
/// This adapter primarily exists as a capability marker and
/// position-preservation wrapper. The actual window manipulation
/// is handled by [PipImpl] in `pip_impl_io.dart`.
///
/// Supported on Windows, macOS, and Linux.
class DesktopPipPlayer implements CrispyPlayer {
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

  Duration _position = Duration.zero;
  final Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1.0;
  double _rate = 1.0;
  String? _currentUrl;
  bool _isMiniWindowActive = false;

  /// Position saved when entering mini-window for restoration.
  Duration _savedPosition = Duration.zero;

  /// Enter mini-window (always-on-top, compact 16:9).
  ///
  /// Saves the current playback position. The actual window
  /// resize is handled by [PipImpl._enterDesktopPiP].
  Future<void> enterMiniWindow() async {
    _savedPosition = _position;
    _isMiniWindowActive = true;
  }

  /// Exit mini-window and restore previous window state.
  ///
  /// Position is preserved — the same player engine continues
  /// throughout the mini-window lifecycle.
  Future<void> exitMiniWindow() async {
    _isMiniWindowActive = false;
    // Position stays at _position — no engine swap occurred.
  }

  /// Whether mini-window mode is currently active.
  bool get isMiniWindowActive => _isMiniWindowActive;

  /// The position saved when entering mini-window.
  Duration get savedPosition => _savedPosition;

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
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _playingCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playingCtrl.add(false);
  }

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
    _isPlaying = false;
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _positionCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _volumeCtrl.add(_volume);
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    _rateCtrl.add(rate);
  }

  @override
  Future<void> setAudioTrack(int index) async {}

  @override
  Future<void> setSubtitleTrack(int index) async {}

  @override
  void setSecondarySubtitleTrack(int index) {}

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
    // Desktop PiP uses the same media_kit video surface —
    // only the window shrinks, not the player engine.
    return const SizedBox.shrink();
  }

  // ── Properties ──────────────────────────────────────

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
  bool get supportsBackgroundAudio => false;

  @override
  Future<Uint8List?> screenshotRawBytes() async => null;

  @override
  String get engineName => 'desktop_pip';

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
