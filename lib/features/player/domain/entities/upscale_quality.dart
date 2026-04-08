/// Video upscaling quality preset.
///
/// Controls the trade-off between visual quality and
/// performance. See `the project video upscaling specification` §5.3.
enum UpscaleQuality {
  /// Lightest processing, minimal GPU load.
  performance('performance', 'Performance', 'Minimal GPU load'),

  /// Default: good quality with reasonable GPU usage.
  balanced('balanced', 'Balanced', 'Best quality/performance ratio'),

  /// Highest quality shader, more GPU intensive.
  maximum('maximum', 'Maximum', 'Best visual quality');

  const UpscaleQuality(this.value, this.label, this.description);

  /// Config/persistence key.
  final String value;

  /// Human-readable label for settings UI.
  final String label;

  /// Short description shown below label.
  final String description;

  /// Resolve from config string, defaulting to [balanced].
  static UpscaleQuality fromValue(String v) => UpscaleQuality.values.firstWhere(
    (q) => q.value == v,
    orElse: () => UpscaleQuality.balanced,
  );
}
