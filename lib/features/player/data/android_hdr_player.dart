import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/crispy_player.dart';

/// [CrispyPlayer] backed by AndroidX Media3 ExoPlayer with SurfaceView
/// for HDR passthrough.
///
/// Communicates with the Kotlin `CrispyHdrPlayerPlugin` via
/// `MethodChannel` and `EventChannel`. The video widget uses
/// Hybrid Composition mode (`AndroidView`) to preserve the native
/// `SurfaceView` hardware compositor HDR path.
///
/// This player is only available on Android and should be registered
/// as a takeover player for [PlayerCapability.hdr].
class AndroidHdrPlayer implements CrispyPlayer {
  static const _channel = MethodChannel('com.crispytivi/hdr_player');
  static const _eventChannel = EventChannel('com.crispytivi/hdr_player/events');

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

  StreamSubscription<dynamic>? _eventSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1.0;
  double _rate = 1.0;
  String? _currentUrl;

  AndroidHdrPlayer() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  /// Query the native plugin for HDR display support.
  static Future<bool> isHdrSupported() async {
    final result = await _channel.invokeMethod<bool>('isHdrSupported');
    return result ?? false;
  }

  /// Query the native plugin for supported HDR codec formats.
  static Future<List<String>> getSupportedFormats() async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'getSupportedHdrFormats',
    );
    return result?.cast<String>() ?? [];
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

  List<CrispyAudioTrack> _audioTracks = [];
  List<CrispySubtitleTrack> _subtitleTracks = [];

  @override
  List<CrispyAudioTrack> get audioTracks => _audioTracks;

  @override
  List<CrispySubtitleTrack> get subtitleTracks => _subtitleTracks;

  // ── Video Widget ────────────────────────────────────

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain}) {
    // Hybrid Composition mode — SurfaceView is added directly
    // to the Android view hierarchy, preserving HDR compositor layer.
    return AndroidView(
      viewType: 'crispy_hdr_player',
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  // ── Properties (no-op for Media3) ──────────────────

  @override
  void setProperty(String key, String value) {}

  @override
  String? getProperty(String key) => null;

  // ── Capabilities ────────────────────────────────────

  @override
  bool get supportsHdr => true;

  @override
  bool get supportsPiP => false;

  @override
  bool get supportsBackgroundAudio => false;

  @override
  String get engineName => 'media3';

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
      case 'tracks':
        _handleTracksUpdate(event);
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

  void _handleTracksUpdate(Map<dynamic, dynamic> event) {
    final audioList = (event['audio'] as List<dynamic>?) ?? [];
    final subtitleList = (event['subtitle'] as List<dynamic>?) ?? [];

    _audioTracks =
        audioList
            .map(
              (t) => CrispyAudioTrack(
                index: t['index'] as int,
                title: t['title'] as String,
                language: t['language'] as String?,
                codec: t['codec'] as String?,
              ),
            )
            .toList();

    _subtitleTracks =
        subtitleList
            .map(
              (t) => CrispySubtitleTrack(
                index: t['index'] as int,
                title: t['title'] as String,
                language: t['language'] as String?,
                codec: t['codec'] as String?,
              ),
            )
            .toList();

    _tracksCtrl.add(
      CrispyTrackList(audio: _audioTracks, subtitle: _subtitleTracks),
    );
  }
}
