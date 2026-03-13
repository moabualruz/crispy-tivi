import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../domain/crispy_player.dart';

/// [CrispyPlayer] backed by media_kit's [Player] + [VideoController].
///
/// This is a thin adapter — no logic changes, just API translation
/// between the [CrispyPlayer] interface and media_kit's concrete types.
///
/// Volume is normalized 0.0–1.0; media_kit uses 0–100 internally.
class MediaKitPlayer implements CrispyPlayer {
  MediaKitPlayer({Player? player}) : _player = player ?? Player();

  final Player _player;
  VideoController? _videoController;
  String? _currentUrl;

  VideoController get _ctrl {
    _videoController ??= VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    return _videoController!;
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

    // LNX-01: Recreate VideoController on Linux to avoid blank
    // screen after stream switch (media-kit#1016).
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.linux &&
        _videoController != null) {
      _videoController = null;
      final _ = _ctrl; // Force recreation
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await _player.open(
      Media(
        url,
        httpHeaders: httpHeaders,
        extras: extras?.map((k, v) => MapEntry(k, v.toString())),
      ),
    );
    if (startPosition > Duration.zero) {
      await _player.seek(startPosition);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> stop() async {
    _currentUrl = null;
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume((volume * 100.0).clamp(0.0, 30000.0));

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setAudioTrack(int index) async {
    final real =
        _player.state.tracks.audio
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
    if (index >= 0 && index < real.length) {
      await _player.setAudioTrack(real[index]);
    }
  }

  @override
  Future<void> setSubtitleTrack(int index) async {
    if (index < 0) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    final real =
        _player.state.tracks.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
    if (index >= 0 && index < real.length) {
      await _player.setSubtitleTrack(real[index]);
    }
  }

  @override
  void setSecondarySubtitleTrack(int index) {
    if (index < 0) {
      setProperty('secondary-sid', 'no');
      return;
    }
    final real =
        _player.state.tracks.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
    if (index >= 0 && index < real.length) {
      setProperty('secondary-sid', real[index].id);
    }
  }

  // ── Streams (delegate + transform) ─────────────────

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<Duration> get bufferStream => _player.stream.buffer;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<String?> get errorStream =>
      _player.stream.error.map((e) => e.isEmpty ? null : e);

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<double> get volumeStream =>
      _player.stream.volume.map((v) => v / 100.0);

  @override
  Stream<double> get rateStream => _player.stream.rate;

  // ── Synchronous State ──────────────────────────────

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  double get volume => _player.state.volume / 100.0;

  @override
  double get rate => _player.state.rate;

  @override
  String? get currentUrl => _currentUrl;

  // ── Tracks ──────────────────────────────────────────

  @override
  List<CrispyAudioTrack> get audioTracks => _mapAudioTracks();

  @override
  List<CrispySubtitleTrack> get subtitleTracks => _mapSubtitleTracks();

  @override
  Stream<CrispyTrackList> get tracksStream => _player.stream.tracks.map(
    (_) => CrispyTrackList(
      audio: _mapAudioTracks(),
      subtitle: _mapSubtitleTracks(),
    ),
  );

  // ── Video Widget ────────────────────────────────────

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain}) {
    return Video(
      controller: _ctrl,
      controls: NoVideoControls,
      fit: fit,
      // Explicit black fill prevents platform-default surface color
      // (white on some Windows/ANGLE backends) from showing before
      // the first video frame is decoded.
      fill: const Color(0xFF000000),
    );
  }

  // ── Properties (mpv passthrough) ────────────────────

  @override
  void setProperty(String key, String value) {
    try {
      (_player.platform as dynamic).setProperty(key, value);
    } catch (
      _
    ) {} // Intentional: dynamic dispatch may not exist on all platforms.
  }

  @override
  String? getProperty(String key) {
    try {
      return (_player.platform as dynamic).getProperty(key) as String?;
    } catch (_) {
      // Intentional: dynamic dispatch may not exist on all platforms.
      return null;
    }
  }

  // ── Capabilities ────────────────────────────────────

  @override
  bool get supportsHdr => false; // Texture widget strips HDR

  @override
  bool get supportsPiP => false; // No AVPlayerLayer

  @override
  bool get supportsBackgroundAudio => true;

  @override
  String get engineName => 'media_kit';

  // ── Audio Device ────────────────────────────────────

  @override
  List<CrispyAudioDevice> get audioDevices {
    try {
      final devices = _player.state.audioDevices;
      return devices
          .map(
            (d) => CrispyAudioDevice(name: d.name, description: d.description),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  String? get currentAudioDeviceName {
    try {
      return _player.state.audioDevice.name;
    } catch (_) {
      return null;
    }
  }

  @override
  void setAudioDevice(String name) {
    try {
      final match = _player.state.audioDevices.where((d) => d.name == name);
      if (match.isNotEmpty) {
        _player.setAudioDevice(match.first);
      }
    } catch (_) {}
  }

  // ── Dispose ─────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _currentUrl = null;
    // IOS-04: Pause and let mpv render thread quiesce before
    // disposing — avoids free_option_data crash (media-kit#1361).
    await _player.pause();
    await Future.delayed(const Duration(milliseconds: 200));
    _videoController = null;
    await _player.dispose();
  }

  // ── Private Helpers ─────────────────────────────────

  List<CrispyAudioTrack> _mapAudioTracks() {
    return _player.state.tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList()
        .asMap()
        .entries
        .map(
          (e) => CrispyAudioTrack(
            index: e.key,
            title: e.value.title ?? e.value.language ?? 'Track ${e.key + 1}',
            language: e.value.language,
          ),
        )
        .toList();
  }

  List<CrispySubtitleTrack> _mapSubtitleTracks() {
    return _player.state.tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList()
        .asMap()
        .entries
        .map(
          (e) => CrispySubtitleTrack(
            index: e.key,
            title: e.value.title ?? e.value.language ?? 'Track ${e.key + 1}',
            language: e.value.language,
          ),
        )
        .toList();
  }
}
