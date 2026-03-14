import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:crispy_tivi/features/player/domain/crispy_player.dart';

/// Manually-controllable mock [CrispyPlayer] for unit tests.
///
/// Tracks method calls and exposes setters for simulating
/// state changes (position, duration, playing, etc.).
class MockCrispyPlayer implements CrispyPlayer {
  // ── Controllable state ──────────────────────────────
  Duration mockPosition = Duration.zero;
  Duration mockDuration = Duration.zero;
  bool mockIsPlaying = false;
  double mockVolume = 1.0;
  double mockRate = 1.0;
  String? mockUrl;

  // ── Call tracking ───────────────────────────────────
  String? lastOpenUrl;
  Duration? lastStartPosition;
  bool pauseCalled = false;
  bool stopCalled = false;
  bool disposeCalled = false;

  // ── Stream controllers ──────────────────────────────
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

  // ── Commands ────────────────────────────────────────

  @override
  Future<void> open(
    String url, {
    Map<String, String>? httpHeaders,
    Map<String, dynamic>? extras,
    Duration startPosition = Duration.zero,
  }) async {
    mockUrl = url;
    lastOpenUrl = url;
    lastStartPosition = startPosition;
    mockPosition = startPosition;
  }

  @override
  Future<void> play() async {
    mockIsPlaying = true;
    _playingCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalled = true;
    mockIsPlaying = false;
    _playingCtrl.add(false);
  }

  @override
  Future<void> playOrPause() async {
    if (mockIsPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
    mockUrl = null;
    mockIsPlaying = false;
  }

  @override
  Future<void> seek(Duration position) async {
    mockPosition = position;
    _positionCtrl.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    mockVolume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> setRate(double rate) async {
    mockRate = rate;
  }

  @override
  Future<void> setAudioTrack(int index) async {}

  @override
  Future<void> setSubtitleTrack(int index) async {}

  @override
  void setSecondarySubtitleTrack(int index) {}

  @override
  Future<void> dispose() async {
    disposeCalled = true;
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
  Duration get position => mockPosition;

  @override
  Duration get duration => mockDuration;

  @override
  bool get isPlaying => mockIsPlaying;

  @override
  double get volume => mockVolume;

  @override
  double get rate => mockRate;

  @override
  String? get currentUrl => mockUrl;

  // ── Tracks ──────────────────────────────────────────

  @override
  List<CrispyAudioTrack> get audioTracks => const [];

  @override
  List<CrispySubtitleTrack> get subtitleTracks => const [];

  // ── Video Widget ────────────────────────────────────

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain}) {
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
  String get engineName => 'mock';

  @override
  List<CrispyAudioDevice> get audioDevices => const [];

  @override
  String? get currentAudioDeviceName => null;

  @override
  void setAudioDevice(String name) {}
}
