import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'hardware_decoder.dart';

void main() {
  group('HardwareDecoder', () {
    test('auto maps to "auto" mpv value', () {
      expect(HardwareDecoder.auto.mpvValue, 'auto');
    });

    test('none maps to "no" mpv value', () {
      expect(HardwareDecoder.none.mpvValue, 'no');
    });

    test('nvdec maps to "nvdec" mpv value', () {
      expect(HardwareDecoder.nvdec.mpvValue, 'nvdec');
    });

    test('d3d11va maps to "d3d11va" mpv value', () {
      expect(HardwareDecoder.d3d11va.mpvValue, 'd3d11va');
    });

    test('vaapi maps to "vaapi" mpv value', () {
      expect(HardwareDecoder.vaapi.mpvValue, 'vaapi');
    });

    test('all decoders have non-empty labels', () {
      for (final d in HardwareDecoder.values) {
        expect(d.label, isNotEmpty);
      }
    });

    test('all decoders have non-empty descriptions', () {
      for (final d in HardwareDecoder.values) {
        expect(d.description, isNotEmpty);
      }
    });

    test('all decoders have non-empty mpvValue', () {
      for (final d in HardwareDecoder.values) {
        expect(d.mpvValue, isNotEmpty);
      }
    });
  });

  group('HardwareDecoder — fromMpvValue', () {
    test('finds auto from "auto"', () {
      expect(HardwareDecoder.fromMpvValue('auto'), HardwareDecoder.auto);
    });

    test('finds none from "no"', () {
      expect(HardwareDecoder.fromMpvValue('no'), HardwareDecoder.none);
    });

    test('finds nvdec from "nvdec"', () {
      expect(HardwareDecoder.fromMpvValue('nvdec'), HardwareDecoder.nvdec);
    });

    test('returns auto for unknown value', () {
      expect(HardwareDecoder.fromMpvValue('nonexistent'), HardwareDecoder.auto);
    });

    test('returns auto for empty string', () {
      expect(HardwareDecoder.fromMpvValue(''), HardwareDecoder.auto);
    });
  });

  group('HardwareDecoder — fromName', () {
    test('finds auto from "auto"', () {
      expect(HardwareDecoder.fromName('auto'), HardwareDecoder.auto);
    });

    test('finds nvdec from "nvdec"', () {
      expect(HardwareDecoder.fromName('nvdec'), HardwareDecoder.nvdec);
    });

    test('returns auto for unknown name', () {
      expect(HardwareDecoder.fromName('nonexistent'), HardwareDecoder.auto);
    });
  });
}
