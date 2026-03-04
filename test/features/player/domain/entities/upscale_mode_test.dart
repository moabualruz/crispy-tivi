import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'upscale_mode.dart';

void main() {
  group('UpscaleMode', () {
    test('auto has correct value', () {
      expect(UpscaleMode.auto.value, 'auto');
    });

    test('off has correct value', () {
      expect(UpscaleMode.off.value, 'off');
    });

    test('forceHardware has correct value', () {
      expect(UpscaleMode.forceHardware.value, 'forceHardware');
    });

    test('forceSoftware has correct value', () {
      expect(UpscaleMode.forceSoftware.value, 'forceSoftware');
    });

    test('all modes have non-empty labels', () {
      for (final m in UpscaleMode.values) {
        expect(m.label, isNotEmpty);
      }
    });

    test('all modes have non-empty descriptions', () {
      for (final m in UpscaleMode.values) {
        expect(m.description, isNotEmpty);
      }
    });

    test('all values are distinct', () {
      final values = UpscaleMode.values.map((m) => m.value).toSet();
      expect(values.length, UpscaleMode.values.length);
    });
  });

  group('UpscaleMode — fromValue', () {
    test('finds auto from "auto"', () {
      expect(UpscaleMode.fromValue('auto'), UpscaleMode.auto);
    });

    test('finds off from "off"', () {
      expect(UpscaleMode.fromValue('off'), UpscaleMode.off);
    });

    test('finds forceHardware from "forceHardware"', () {
      expect(UpscaleMode.fromValue('forceHardware'), UpscaleMode.forceHardware);
    });

    test('finds forceSoftware from "forceSoftware"', () {
      expect(UpscaleMode.fromValue('forceSoftware'), UpscaleMode.forceSoftware);
    });

    test('returns auto for unknown value', () {
      expect(UpscaleMode.fromValue('nonexistent'), UpscaleMode.auto);
    });

    test('returns auto for empty string', () {
      expect(UpscaleMode.fromValue(''), UpscaleMode.auto);
    });
  });
}
