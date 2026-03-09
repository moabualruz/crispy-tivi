import 'dart:math';

import 'package:flutter/material.dart';

/// A compact rolling-history sparkline chart.
///
/// Renders a line connecting [samples] points with color-coded
/// segments: green above [highThreshold], yellow between
/// thresholds, red below [lowThreshold]. The area under the line
/// is filled at 20% opacity. Dashed horizontal threshold lines
/// are drawn for visual reference.
///
/// Used in the stream stats overlay for buffer duration and FPS
/// history. The parent widget manages the rolling sample buffer
/// and passes it here each frame.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.samples,
    this.minValue = 0,
    this.maxValue = 100,
    this.lowThreshold = 20,
    this.highThreshold = 60,
    this.width = 80,
    this.height = 24,
    this.strokeWidth = 1.5,
    super.key,
  });

  /// Data points to plot (oldest first, newest last).
  final List<double> samples;

  /// Y-axis minimum.
  final double minValue;

  /// Y-axis maximum.
  final double maxValue;

  /// Below this value, the line turns red.
  final double lowThreshold;

  /// Above this value, the line turns green.
  final double highThreshold;

  /// Chart width in logical pixels.
  final double width;

  /// Chart height in logical pixels.
  final double height;

  /// Line stroke width.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(
        samples: samples,
        minValue: minValue,
        maxValue: maxValue,
        lowThreshold: lowThreshold,
        highThreshold: highThreshold,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.samples,
    required this.minValue,
    required this.maxValue,
    required this.lowThreshold,
    required this.highThreshold,
    required this.strokeWidth,
  });

  final List<double> samples;
  final double minValue;
  final double maxValue;
  final double lowThreshold;
  final double highThreshold;
  final double strokeWidth;

  static const _green = Color(0xFF4CAF50);
  static const _yellow = Color(0xFFFFC107);
  static const _red = Color(0xFFF44336);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    final range = maxValue - minValue;
    if (range <= 0) return;

    // Build points.
    final count = samples.length;
    final dx = size.width / (count - 1);
    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final v = samples[i].clamp(minValue, maxValue);
      final y = size.height - ((v - minValue) / range * size.height);
      points.add(Offset(i * dx, y));
    }

    // Draw dashed threshold lines.
    _drawDashedLine(
      canvas,
      size,
      size.height - ((lowThreshold - minValue) / range * size.height),
    );
    _drawDashedLine(
      canvas,
      size,
      size.height - ((highThreshold - minValue) / range * size.height),
    );

    // Draw filled area under the line.
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final lastValue = samples.last.clamp(minValue, maxValue);
    final baseColor = _colorForValue(lastValue);
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = baseColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );

    // Draw line segments with per-segment color.
    for (var i = 0; i < points.length - 1; i++) {
      final v = samples[i].clamp(minValue, maxValue);
      final color = _colorForValue(v);
      canvas.drawLine(
        points[i],
        points[i + 1],
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  Color _colorForValue(double v) {
    if (v >= highThreshold) return _green;
    if (v <= lowThreshold) return _red;
    return _yellow;
  }

  void _drawDashedLine(Canvas canvas, Size size, double y) {
    if (y < 0 || y > size.height) return;

    final paint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    const dashWidth = 3.0;
    const gapWidth = 3.0;
    var x = 0.0;
    while (x < size.width) {
      final end = min(x + dashWidth, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return !_listEquals(oldDelegate.samples, samples) ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lowThreshold != lowThreshold ||
        oldDelegate.highThreshold != highThreshold;
  }

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
