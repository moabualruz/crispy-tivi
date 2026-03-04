/// Video upscaling mode.
///
/// Controls how the app selects an upscaling method.
/// See `.ai/docs/project-specs/video_upscaling_spec.md` §5.2.
enum UpscaleMode {
  /// Auto-detect GPU and apply best available method.
  auto('auto', 'Auto', 'Best available method'),

  /// Disable all upscaling. Use default bilinear.
  off('off', 'Off', 'No upscaling applied'),

  /// Always use hardware VSR if available.
  forceHardware('forceHardware', 'Force Hardware', 'Requires compatible GPU'),

  /// Always use FSR/ewa_lanczos shader.
  forceSoftware('forceSoftware', 'Force Software', 'Works on all platforms');

  const UpscaleMode(this.value, this.label, this.description);

  /// Config/persistence key.
  final String value;

  /// Human-readable label for settings UI.
  final String label;

  /// Short description shown below label.
  final String description;

  /// Resolve from config string, defaulting to [auto].
  static UpscaleMode fromValue(String v) => UpscaleMode.values.firstWhere(
    (m) => m.value == v,
    orElse: () => UpscaleMode.auto,
  );
}
