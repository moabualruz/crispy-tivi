import '../../../../core/utils/platform_info.dart';

/// Audio output driver options for mpv player.
///
/// Maps to mpv's `ao` (audio output) property.
/// Platform-specific options are filtered by [availableForCurrentPlatform].
enum AudioOutput {
  /// Automatic audio output selection (default).
  auto(
    label: 'Auto',
    mpvValue: 'auto',
    description: 'Automatically select best audio output',
    platforms: {AudioPlatform.all},
  ),

  /// S/PDIF digital audio output.
  spdif(
    label: 'S/PDIF',
    mpvValue: 'spdif',
    description: 'Digital audio via optical/coaxial',
    platforms: {AudioPlatform.windows, AudioPlatform.linux},
  ),

  /// WASAPI audio output (Windows).
  wasapi(
    label: 'WASAPI',
    mpvValue: 'wasapi',
    description: 'Windows Audio Session API',
    platforms: {AudioPlatform.windows},
  ),

  /// PulseAudio output (Linux).
  pulse(
    label: 'PulseAudio',
    mpvValue: 'pulse',
    description: 'PulseAudio sound server',
    platforms: {AudioPlatform.linux},
  ),

  /// ALSA audio output (Linux).
  alsa(
    label: 'ALSA',
    mpvValue: 'alsa',
    description: 'Advanced Linux Sound Architecture',
    platforms: {AudioPlatform.linux},
  ),

  /// PipeWire audio output (Linux).
  pipewire(
    label: 'PipeWire',
    mpvValue: 'pipewire',
    description: 'PipeWire multimedia server',
    platforms: {AudioPlatform.linux},
  ),

  /// CoreAudio output (macOS).
  coreaudio(
    label: 'CoreAudio',
    mpvValue: 'coreaudio',
    description: 'macOS native audio',
    platforms: {AudioPlatform.macos},
  ),

  /// AAudio output (Android).
  aaudio(
    label: 'AAudio',
    mpvValue: 'aaudio',
    description: 'Android native audio',
    platforms: {AudioPlatform.android},
  ),

  /// OpenSL ES output (Android).
  opensles(
    label: 'OpenSL ES',
    mpvValue: 'opensles',
    description: 'Android OpenSL ES audio',
    platforms: {AudioPlatform.android},
  );

  const AudioOutput({
    required this.label,
    required this.mpvValue,
    required this.description,
    required this.platforms,
  });

  /// Display label for UI.
  final String label;

  /// Value to pass to mpv's `ao` option.
  final String mpvValue;

  /// Description of this audio output.
  final String description;

  /// Platforms this output is available on.
  final Set<AudioPlatform> platforms;

  /// Whether this output is available on the current platform.
  bool get isAvailableOnCurrentPlatform {
    if (platforms.contains(AudioPlatform.all)) return true;
    if (PlatformInfo.instance.isWeb) return false;

    final p = PlatformInfo.instance;
    if (p.isWindows) return platforms.contains(AudioPlatform.windows);
    if (p.isLinux) return platforms.contains(AudioPlatform.linux);
    if (p.isMacOS) return platforms.contains(AudioPlatform.macos);
    if (p.isAndroid) return platforms.contains(AudioPlatform.android);
    if (p.isIOS) return platforms.contains(AudioPlatform.ios);

    return false;
  }

  /// Gets all audio outputs available on the current platform.
  static List<AudioOutput> get availableForCurrentPlatform {
    return values.where((o) => o.isAvailableOnCurrentPlatform).toList();
  }

  /// Finds an AudioOutput by its mpv value, or returns [auto] if not found.
  static AudioOutput fromMpvValue(String value) {
    return values.firstWhere((o) => o.mpvValue == value, orElse: () => auto);
  }
}

/// Platform enum for audio output filtering.
enum AudioPlatform { all, windows, linux, macos, android, ios }
