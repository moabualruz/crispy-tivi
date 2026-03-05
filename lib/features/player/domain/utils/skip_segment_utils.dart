import '../entities/playback_state.dart';

/// Returns a human-readable skip label for [seg] given the full
/// ordered [segments] list.
///
/// Heuristic:
///   - first segment  → "Skip Intro"
///   - last segment   → "Skip Credits"
///   - middle segment → "Skip Recap"
String segmentLabel(SkipSegment seg, List<SkipSegment> segments) {
  final idx = segments.indexOf(seg);
  if (idx == 0) return 'Skip Intro';
  if (idx == segments.length - 1) return 'Skip Credits';
  return 'Skip Recap';
}
