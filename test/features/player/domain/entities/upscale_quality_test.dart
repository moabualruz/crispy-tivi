import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'upscale_quality.dart';

void main() {
  group('UpscaleQuality', () {
    test('performance has correct value', () {
      expect(UpscaleQuality.performance.value, 'performance');
    });

    test('balanced has correct value', () {
      expect(UpscaleQuality.balanced.value, 'balanced');
    });

    test('maximum has correct value', () {
      expect(UpscaleQuality.maximum.value, 'maximum');
    });

    test('all qualities have non-empty labels', () {
      for (final q in UpscaleQuality.values) {
        expect(q.label, isNotEmpty);
      }
    });

    test('all qualities have non-empty descriptions', () {
      for (final q in UpscaleQuality.values) {
        expect(q.description, isNotEmpty);
      }
    });

    test('all values are distinct', () {
      final values = UpscaleQuality.values.map((q) => q.value).toSet();
      expect(values.length, UpscaleQuality.values.length);
    });
  });

  group('UpscaleQuality — fromValue', () {
    test('finds performance from "performance"', () {
      expect(
        UpscaleQuality.fromValue('performance'),
        UpscaleQuality.performance,
      );
    });

    test('finds balanced from "balanced"', () {
      expect(UpscaleQuality.fromValue('balanced'), UpscaleQuality.balanced);
    });

    test('finds maximum from "maximum"', () {
      expect(UpscaleQuality.fromValue('maximum'), UpscaleQuality.maximum);
    });

    test('returns balanced for unknown value', () {
      expect(UpscaleQuality.fromValue('nonexistent'), UpscaleQuality.balanced);
    });

    test('returns balanced for empty string', () {
      expect(UpscaleQuality.fromValue(''), UpscaleQuality.balanced);
    });
  });
}
