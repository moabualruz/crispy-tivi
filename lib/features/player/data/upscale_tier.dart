/// A single tier in the upscaling fallback chain.
///
/// Each tier wraps a named upscaling method with an
/// [apply] function that returns `true` on success.
/// Tiers are tried in order; the first to succeed wins.
///
/// See `the project video upscaling specification` §4.4 for the
/// full fallback chain design.
class UpscaleTier {
  /// Creates an immutable upscale tier.
  const UpscaleTier({
    required this.level,
    required this.name,
    required this.apply,
  });

  /// Tier level (1 = HW AI, 2 = HW spatial,
  /// 3 = SW quality, 4 = SW fast).
  final int level;

  /// Human-readable tier name (e.g. 'FSR GLSL').
  final String name;

  /// Attempts to activate this tier.
  ///
  /// Returns `true` if the upscaling method was applied
  /// successfully, `false` if unavailable. May throw on
  /// unexpected errors — callers must catch.
  final Future<bool> Function() apply;

  @override
  String toString() => 'UpscaleTier($level: $name)';
}
