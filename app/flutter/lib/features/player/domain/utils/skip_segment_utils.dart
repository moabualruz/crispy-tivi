import '../entities/playback_state.dart';
import '../segment_skip_config.dart';

/// Resolves the [SegmentType] for [seg].
///
/// Returns [SkipSegment.type] if explicitly set (e.g. from
/// Jellyfin/Emby metadata), otherwise infers from position:
///   - first segment  → [SegmentType.intro]
///   - last segment   → [SegmentType.outro]
///   - middle segment → [SegmentType.recap]
SegmentType inferSegmentType(SkipSegment seg, List<SkipSegment> segments) {
  if (seg.type != null) return seg.type!;
  final idx = segments.indexOf(seg);
  if (idx == 0) return SegmentType.intro;
  if (idx == segments.length - 1) return SegmentType.outro;
  return SegmentType.recap;
}

/// Returns a human-readable skip label for [seg] given the full
/// ordered [segments] list.
///
/// Uses [inferSegmentType] to determine the label.
String segmentLabel(SkipSegment seg, List<SkipSegment> segments) {
  final type = inferSegmentType(seg, segments);
  return 'Skip ${type.label}';
}
