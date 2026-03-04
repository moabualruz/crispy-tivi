/// Audio codecs supported for S/PDIF/HDMI passthrough.
///
/// When audio passthrough is enabled, these codecs are sent as bitstream
/// directly to the AV receiver without decoding.
///
/// Maps to mpv's `audio-spdif` option values.
enum PassthroughCodec {
  /// Dolby Digital (AC-3) - standard 5.1 surround.
  ac3(
    label: 'Dolby Digital (AC3)',
    mpvValue: 'ac3',
    description: 'Standard Dolby 5.1 surround sound',
    maxChannels: 6,
  ),

  /// Dolby Digital Plus (E-AC-3) - enhanced Dolby.
  eac3(
    label: 'Dolby Digital Plus',
    mpvValue: 'eac3',
    description: 'Enhanced Dolby up to 7.1 channels',
    maxChannels: 8,
  ),

  /// Dolby TrueHD - lossless Dolby (Blu-ray).
  truehd(
    label: 'Dolby TrueHD',
    mpvValue: 'truehd',
    description: 'Lossless Dolby for Blu-ray',
    maxChannels: 8,
  ),

  /// Dolby Atmos - object-based 3D audio (carried over TrueHD/DD+).
  atmos(
    label: 'Dolby Atmos',
    mpvValue: 'truehd',
    description: 'Object-based 3D audio (via TrueHD)',
    maxChannels: 16,
  ),

  /// DTS - standard DTS 5.1 surround.
  dts(
    label: 'DTS',
    mpvValue: 'dts',
    description: 'Standard DTS 5.1 surround sound',
    maxChannels: 6,
  ),

  /// DTS-HD Master Audio - lossless DTS (Blu-ray).
  dtsHd(
    label: 'DTS-HD Master Audio',
    mpvValue: 'dts-hd',
    description: 'Lossless DTS for Blu-ray',
    maxChannels: 8,
  ),

  /// DTS:X - object-based 3D audio (carried over DTS-HD).
  dtsX(
    label: 'DTS:X',
    mpvValue: 'dts-hd',
    description: 'Object-based 3D audio (via DTS-HD)',
    maxChannels: 16,
  );

  const PassthroughCodec({
    required this.label,
    required this.mpvValue,
    required this.description,
    required this.maxChannels,
  });

  /// Display label for UI.
  final String label;

  /// Value to pass to mpv's `audio-spdif` option.
  final String mpvValue;

  /// Description of this codec.
  final String description;

  /// Maximum channel count supported.
  final int maxChannels;

  /// Finds a PassthroughCodec by its mpv value.
  static PassthroughCodec? fromMpvValue(String value) {
    return values.where((c) => c.mpvValue == value).firstOrNull;
  }

  /// Converts a list of mpv codec strings to PassthroughCodec enums.
  static List<PassthroughCodec> fromMpvValues(List<String> values) {
    final result = <PassthroughCodec>[];
    for (final value in values) {
      // Map to unique codecs (avoid duplicates from atmos/dtsX)
      final codec = PassthroughCodec.values.firstWhere(
        (c) => c.mpvValue == value && c != atmos && c != dtsX,
        orElse:
            () => PassthroughCodec.values.firstWhere(
              (c) => c.mpvValue == value,
              orElse: () => PassthroughCodec.ac3,
            ),
      );
      if (!result.contains(codec)) {
        result.add(codec);
      }
    }
    return result;
  }

  /// Converts a list of PassthroughCodec enums to mpv codec strings.
  /// Removes duplicates (e.g., atmos and truehd both map to 'truehd').
  static List<String> toMpvValues(List<PassthroughCodec> codecs) {
    return codecs.map((c) => c.mpvValue).toSet().toList();
  }

  /// Default codecs for basic surround sound support.
  static List<PassthroughCodec> get defaultCodecs => [ac3, dts];

  /// All lossless codecs for high-quality setups.
  static List<PassthroughCodec> get losslessCodecs => [truehd, dtsHd];

  /// All Dolby family codecs.
  static List<PassthroughCodec> get dolbyCodecs => [ac3, eac3, truehd, atmos];

  /// All DTS family codecs.
  static List<PassthroughCodec> get dtsCodecs => [dts, dtsHd, dtsX];
}
