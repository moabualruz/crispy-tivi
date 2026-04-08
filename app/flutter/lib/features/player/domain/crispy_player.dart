import 'dart:async';
import 'dart:typed_data';

// DDD exception: player interface defines the rendering contract
import 'package:flutter/widgets.dart';

/// Abstract player backend interface.
///
/// CrispyTivi's presentation layer (PlayerService, OSD, providers)
/// programs against this interface. Concrete implementations wrap
/// specific player engines (media_kit, Media3, AVPlayer, etc.).
///
/// ## Lifecycle
///
/// ```
/// create → open(url) → [play/pause/seek] → stop → dispose
///                  ↑                         │
///                  └─────────────────────────┘  (can re-open)
/// ```
///
/// ## Streams
///
/// All streams are broadcast streams. Subscribers receive
/// updates as long as the player is not disposed. Position
/// stream fires at the engine's native rate (~60Hz for mpv,
/// ~30Hz for Media3) — consumers are responsible for
/// throttling in the UI layer.
abstract class CrispyPlayer {
  // ── Playback Commands ────────────────────────────────

  /// Load and start playing a media URL.
  ///
  /// [extras] are engine-specific key-value pairs (e.g., mpv
  /// options like `cache`, `demuxer-lavf-o`). Implementations
  /// that don't support extras silently ignore them.
  Future<void> open(
    String url, {
    Map<String, String>? httpHeaders,
    Map<String, dynamic>? extras,
    Duration startPosition = Duration.zero,
  });

  /// Start/resume playback.
  Future<void> play();

  /// Pause playback.
  Future<void> pause();

  /// Toggle play/pause.
  Future<void> playOrPause();

  /// Stop playback and release media resources.
  /// Player can be re-opened after stop.
  Future<void> stop();

  /// Seek to [position].
  Future<void> seek(Duration position);

  /// Set volume (0.0 = mute, 1.0 = full).
  Future<void> setVolume(double volume);

  /// Set playback speed (0.25 – 4.0).
  Future<void> setRate(double rate);

  /// Select audio track by index into [audioTracks].
  Future<void> setAudioTrack(int index);

  /// Select subtitle track by index, or -1 to disable.
  Future<void> setSubtitleTrack(int index);

  /// Select a secondary subtitle track by index, or -1 to
  /// disable. Uses mpv `secondary-sid` for dual display.
  /// No-op on engines that don't support it.
  void setSecondarySubtitleTrack(int index);

  /// Release all resources. Player cannot be used after.
  Future<void> dispose();

  // ── Streams ──────────────────────────────────────────

  /// Position updates (high frequency — throttle in UI).
  Stream<Duration> get positionStream;

  /// Duration updates (fires on media load and change).
  Stream<Duration> get durationStream;

  /// Buffered position updates.
  Stream<Duration> get bufferStream;

  /// Playing state changes.
  Stream<bool> get playingStream;

  /// Fires `true` when media reaches end.
  Stream<bool> get completedStream;

  /// Error messages. `null` clears error state.
  Stream<String?> get errorStream;

  /// Buffering state changes.
  Stream<bool> get bufferingStream;

  /// Volume changes (0.0 – 1.0, normalized).
  Stream<double> get volumeStream;

  /// Playback rate changes.
  Stream<double> get rateStream;

  // ── Synchronous State ────────────────────────────────

  /// Current playback position.
  Duration get position;

  /// Current media duration.
  Duration get duration;

  /// Whether the player is currently playing.
  bool get isPlaying;

  /// Current volume (0.0 – 1.0).
  double get volume;

  /// Current playback rate.
  double get rate;

  /// The URL of the currently loaded media, or `null` if
  /// nothing is loaded.
  String? get currentUrl;

  // ── Track Info ───────────────────────────────────────

  /// Available audio tracks.
  List<CrispyAudioTrack> get audioTracks;

  /// Available subtitle tracks.
  List<CrispySubtitleTrack> get subtitleTracks;

  /// Stream of track list changes (fires on media load).
  Stream<CrispyTrackList> get tracksStream;

  // ── Screenshot ──────────────────────────────────────

  /// Capture the current video frame as raw JPEG bytes.
  ///
  /// Returns `null` if no media is loaded, the engine does
  /// not support frame capture, or an error occurs.
  Future<Uint8List?> screenshotRawBytes() async => null;

  // ── Video Widget ─────────────────────────────────────

  /// Build the platform-specific video rendering widget.
  ///
  /// Returned widget must be embeddable in a [Stack] — it
  /// renders the video surface only, no controls.
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain});

  // ── Engine Properties ────────────────────────────────

  /// Set an engine-specific property (e.g., mpv `hwdec`,
  /// `deinterlace`, `af`). No-op on engines that don't
  /// support property systems.
  void setProperty(String key, String value);

  /// Get an engine-specific property. Returns `null` if
  /// the engine doesn't support properties or the key
  /// is unknown.
  String? getProperty(String key);

  // ── Capability Queries ───────────────────────────────

  /// Whether this backend supports HDR passthrough.
  bool get supportsHdr;

  /// Whether this backend supports Picture-in-Picture.
  bool get supportsPiP;

  /// Whether this backend supports background audio.
  bool get supportsBackgroundAudio;

  /// Engine identifier for diagnostics (e.g., 'media_kit',
  /// 'media3', 'avplayer').
  String get engineName;

  // ── Audio Device ───────────────────────────────────

  /// Available audio output devices.
  ///
  /// Returns an empty list on engines that don't support
  /// device enumeration.
  List<CrispyAudioDevice> get audioDevices;

  /// Name of the currently selected audio device.
  String? get currentAudioDeviceName;

  /// Select an audio output device by name.
  void setAudioDevice(String name);
}

// ── Supporting Types ─────────────────────────────────────

/// Audio output device info (engine-agnostic).
class CrispyAudioDevice {
  const CrispyAudioDevice({required this.name, required this.description});

  /// Engine-specific device identifier (e.g. 'auto',
  /// 'wasapi/{...}').
  final String name;

  /// Human-readable device description.
  final String description;
}

/// Audio track info (engine-agnostic).
class CrispyAudioTrack {
  const CrispyAudioTrack({
    required this.index,
    required this.title,
    this.language,
    this.codec,
    this.channels,
    this.bitrate,
  });

  final int index;
  final String title;
  final String? language;
  final String? codec;
  final int? channels;
  final int? bitrate;
}

/// Subtitle track info (engine-agnostic).
class CrispySubtitleTrack {
  const CrispySubtitleTrack({
    required this.index,
    required this.title,
    this.language,
    this.codec,
  });

  final int index;
  final String title;
  final String? language;
  final String? codec;
}

/// Combined track list snapshot.
class CrispyTrackList {
  const CrispyTrackList({this.audio = const [], this.subtitle = const []});

  final List<CrispyAudioTrack> audio;
  final List<CrispySubtitleTrack> subtitle;
}

// ── Capability Constants ─────────────────────────────────

/// Capability identifiers for handoff registration.
abstract class PlayerCapability {
  static const String hdr = 'hdr';
  static const String pip = 'pip';
}
