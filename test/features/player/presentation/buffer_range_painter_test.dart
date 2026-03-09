import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/presentation/widgets/buffer_range_painter.dart';

void main() {
  group('BufferRangePainter', () {
    test('shouldRepaint returns false for identical ranges', () {
      final a = BufferRangePainter(
        ranges: const [(0.0, 0.5)],
        color: Colors.blue,
      );
      final b = BufferRangePainter(
        ranges: const [(0.0, 0.5)],
        color: Colors.blue,
      );

      expect(a.shouldRepaint(b), isFalse);
    });

    test('shouldRepaint returns true for different ranges', () {
      final a = BufferRangePainter(
        ranges: const [(0.0, 0.5)],
        color: Colors.blue,
      );
      final b = BufferRangePainter(
        ranges: const [(0.0, 0.7)],
        color: Colors.blue,
      );

      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint returns true for different color', () {
      final a = BufferRangePainter(
        ranges: const [(0.0, 0.5)],
        color: Colors.blue,
      );
      final b = BufferRangePainter(
        ranges: const [(0.0, 0.5)],
        color: Colors.red,
      );

      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint returns true for different range count', () {
      final a = BufferRangePainter(
        ranges: const [(0.0, 0.3), (0.5, 0.8)],
        color: Colors.blue,
      );
      final b = BufferRangePainter(
        ranges: const [(0.0, 0.3)],
        color: Colors.blue,
      );

      expect(a.shouldRepaint(b), isTrue);
    });

    testWidgets('renders with empty ranges', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(200, 6),
              painter: BufferRangePainter(ranges: const [], color: Colors.blue),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with single range', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(200, 6),
              painter: BufferRangePainter(
                ranges: const [(0.0, 0.5)],
                color: Colors.blue.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with multiple non-contiguous ranges', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(200, 6),
              painter: BufferRangePainter(
                ranges: const [(0.0, 0.2), (0.3, 0.5), (0.7, 0.9)],
                color: Colors.blue.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('skips degenerate ranges where end <= start', () {
      final painter = BufferRangePainter(
        ranges: const [(0.5, 0.3), (0.0, 0.0), (0.2, 0.4)],
        color: Colors.blue,
      );

      // Verify it doesn't throw when painting.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 6));
      recorder.endRecording();
    });

    test('clamps ranges to 0.0-1.0', () {
      final painter = BufferRangePainter(
        ranges: const [(-0.1, 1.2)],
        color: Colors.blue,
      );

      // Should not throw.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 6));
      recorder.endRecording();
    });
  });
}
