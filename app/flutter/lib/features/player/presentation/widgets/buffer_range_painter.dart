import 'package:flutter/material.dart';

/// Paints multiple non-contiguous buffer cache ranges on the
/// seek bar track.
///
/// Each range in [ranges] is a normalized `(start, end)` pair
/// where 0.0 = beginning and 1.0 = end of the video. Ranges
/// are rendered as semi-transparent colored bars overlaid on
/// the seek bar background, showing all buffered segments at
/// a glance.
///
/// Uses fraction clamping, `drawRRect` per range, and skips
/// degenerate ranges.
class BufferRangePainter extends CustomPainter {
  BufferRangePainter({
    required this.ranges,
    required this.color,
    this.trackHeight = 3.0,
  });

  /// Normalized `(start, end)` pairs — 0.0 to 1.0.
  final List<(double start, double end)> ranges;

  /// Fill color for cached ranges (typically primary at 30%
  /// opacity).
  final Color color;

  /// Height of each range bar in logical pixels.
  final double trackHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (ranges.isEmpty) return;

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final y = (size.height - trackHeight) / 2;

    for (final range in ranges) {
      final start = range.$1.clamp(0.0, 1.0);
      final end = range.$2.clamp(0.0, 1.0);
      if (end <= start) continue;

      final left = start * size.width;
      final right = end * size.width;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y, right - left, trackHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BufferRangePainter oldDelegate) {
    return !_rangesEqual(oldDelegate.ranges, ranges) ||
        oldDelegate.color != color ||
        oldDelegate.trackHeight != trackHeight;
  }

  static bool _rangesEqual(List<(double, double)> a, List<(double, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].$1 != b[i].$1 || a[i].$2 != b[i].$2) return false;
    }
    return true;
  }
}
