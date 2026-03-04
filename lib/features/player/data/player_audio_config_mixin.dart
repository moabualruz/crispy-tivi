part of 'player_service.dart';

/// Audio output, hardware decoder, and stream profile
/// configuration.
///
/// Provides public getters and setters for the config
/// fields defined in [PlayerServiceBase]. These settings
/// are applied when [openMedia] builds the mpv extras
/// map.
mixin PlayerAudioConfigMixin on PlayerServiceBase {
  // ── Stream Profile ───────────────────────────────────

  /// Current stream quality profile.
  StreamProfile get streamProfile => _streamProfile;

  /// Sets the stream quality profile for new streams.
  void setStreamProfile(StreamProfile profile) {
    _streamProfile = profile;
    debugPrint(
      'PlayerService: stream profile '
      'set to ${profile.label}',
    );
  }

  // ── Hardware Decoder ─────────────────────────────────

  /// Current hardware decoder mode.
  String get hwdecMode => _hwdecMode;

  /// Sets the hardware decoder mode.
  ///
  /// Supported values:
  /// - 'auto': Let mpv choose the best available
  /// - 'no': Force software decoding
  /// - Specific: 'nvdec', 'd3d11va', 'vaapi', etc.
  void setHwdecMode(String mode) {
    _hwdecMode = mode;
    debugPrint('PlayerService: hwdec mode set to $mode');
  }

  // ── Audio Output ─────────────────────────────────────

  /// Current audio output driver.
  String get audioOutput => _audioOutput;

  /// Sets the audio output driver.
  ///
  /// Supported values depend on platform:
  /// - 'auto': Let mpv choose the best output
  /// - 'wasapi': Windows Audio Session API
  /// - 'pulse': PulseAudio (Linux)
  /// - 'alsa': ALSA (Linux)
  /// - 'coreaudio': CoreAudio (macOS)
  /// - 'spdif': S/PDIF passthrough
  /// - 'hdmi': HDMI audio output
  void setAudioOutput(String output) {
    _audioOutput = output;
    debugPrint('PlayerService: audio output set to $output');
  }

  // ── Audio Passthrough ────────────────────────────────

  /// Whether audio passthrough is enabled.
  bool get audioPassthroughEnabled => _audioPassthroughEnabled;

  /// Current passthrough codec list.
  List<String> get audioPassthroughCodecs =>
      List.unmodifiable(_audioPassthroughCodecs);

  /// Sets audio passthrough configuration.
  ///
  /// When enabled, the specified codecs are passed
  /// through as bitstream directly to the AV receiver
  /// without decoding.
  ///
  /// Common codec values: 'ac3', 'dts', 'eac3',
  /// 'truehd', 'dts-hd'.
  void setAudioPassthrough(bool enabled, List<String> codecs) {
    _audioPassthroughEnabled = enabled;
    _audioPassthroughCodecs = List.from(codecs);
    debugPrint(
      'PlayerService: audio passthrough '
      '${enabled ? "enabled" : "disabled"}, '
      'codecs: ${codecs.join(", ")}',
    );
  }
}
