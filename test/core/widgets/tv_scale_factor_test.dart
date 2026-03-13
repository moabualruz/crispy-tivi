import 'package:crispy_tivi/core/widgets/tv_scale_factor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeTvScaleFactor', () {
    test('returns 1.0 for 1080p resolution (1920 physical width)', () {
      expect(computeTvScaleFactor(1920), 1.0);
    });

    test('returns 1.0 for sub-1080p resolution (1280 physical width)', () {
      expect(computeTvScaleFactor(1280), 1.0);
    });

    test('returns ~1.25 for 1440p resolution (2560 physical width)', () {
      expect(computeTvScaleFactor(2560), closeTo(1.25, 0.01));
    });

    test('returns ~1.5 for 4K resolution (3840 physical width)', () {
      expect(computeTvScaleFactor(3840), closeTo(1.5, 0.01));
    });

    test('interpolates between 1080p and 1440p', () {
      // Midpoint: (1920 + 2560) / 2 = 2240
      final factor = computeTvScaleFactor(2240);
      expect(factor, closeTo(1.125, 0.01));
    });

    test('interpolates between 1440p and 4K', () {
      // Midpoint: (2560 + 3840) / 2 = 3200
      final factor = computeTvScaleFactor(3200);
      expect(factor, closeTo(1.375, 0.01));
    });

    test('caps at 1.5 for resolutions above 4K', () {
      expect(computeTvScaleFactor(5120), 1.5);
      expect(computeTvScaleFactor(7680), 1.5);
    });
  });

  group('TvScaleFactor widget', () {
    testWidgets('applies text scale factor to child', (tester) async {
      // Simulate a 4K TV: 3840x2160 physical, devicePixelRatio=2.0
      // => logical size 1920x1080, physical width = 3840
      tester.view.physicalSize = const Size(3840, 2160);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late double capturedScaleFactor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvScaleFactor(
              child: Builder(
                builder: (context) {
                  capturedScaleFactor = MediaQuery.of(
                    context,
                  ).textScaler.scale(1.0);
                  return const Text('test');
                },
              ),
            ),
          ),
        ),
      );

      // 3840 physical width => scale factor 1.5
      expect(capturedScaleFactor, closeTo(1.5, 0.01));
    });

    testWidgets('does not scale at 1080p resolution', (tester) async {
      // 1080p TV: 1920x1080 physical, devicePixelRatio=1.0
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late double capturedScaleFactor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvScaleFactor(
              child: Builder(
                builder: (context) {
                  capturedScaleFactor = MediaQuery.of(
                    context,
                  ).textScaler.scale(1.0);
                  return const Text('test');
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedScaleFactor, 1.0);
    });
  });
}
