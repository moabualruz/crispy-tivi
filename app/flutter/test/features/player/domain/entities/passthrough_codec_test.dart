import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'passthrough_codec.dart';

void main() {
  group('PassthroughCodec', () {
    test('ac3 has correct mpv value and channels', () {
      expect(PassthroughCodec.ac3.mpvValue, 'ac3');
      expect(PassthroughCodec.ac3.maxChannels, 6);
    });

    test('eac3 has correct mpv value and channels', () {
      expect(PassthroughCodec.eac3.mpvValue, 'eac3');
      expect(PassthroughCodec.eac3.maxChannels, 8);
    });

    test('truehd has correct mpv value', () {
      expect(PassthroughCodec.truehd.mpvValue, 'truehd');
    });

    test('atmos shares truehd mpv value but has 16 ch', () {
      expect(PassthroughCodec.atmos.mpvValue, 'truehd');
      expect(PassthroughCodec.atmos.maxChannels, 16);
    });

    test('dts has correct mpv value and channels', () {
      expect(PassthroughCodec.dts.mpvValue, 'dts');
      expect(PassthroughCodec.dts.maxChannels, 6);
    });

    test('dtsHd has correct mpv value', () {
      expect(PassthroughCodec.dtsHd.mpvValue, 'dts-hd');
      expect(PassthroughCodec.dtsHd.maxChannels, 8);
    });

    test('dtsX shares dts-hd mpv value but has 16 ch', () {
      expect(PassthroughCodec.dtsX.mpvValue, 'dts-hd');
      expect(PassthroughCodec.dtsX.maxChannels, 16);
    });

    test('all codecs have non-empty labels', () {
      for (final c in PassthroughCodec.values) {
        expect(c.label, isNotEmpty);
      }
    });
  });

  group('PassthroughCodec — fromMpvValue', () {
    test('finds ac3 from "ac3"', () {
      expect(PassthroughCodec.fromMpvValue('ac3'), PassthroughCodec.ac3);
    });

    test('finds dts from "dts"', () {
      expect(PassthroughCodec.fromMpvValue('dts'), PassthroughCodec.dts);
    });

    test('returns null for unknown value', () {
      expect(PassthroughCodec.fromMpvValue('unknown'), isNull);
    });
  });

  group('PassthroughCodec — fromMpvValues', () {
    test('parses list of mpv strings', () {
      final result = PassthroughCodec.fromMpvValues(['ac3', 'dts']);
      expect(result, hasLength(2));
      expect(result[0], PassthroughCodec.ac3);
      expect(result[1], PassthroughCodec.dts);
    });

    test('deduplicates shared mpv values', () {
      // truehd is shared by truehd and atmos
      final result = PassthroughCodec.fromMpvValues(['truehd']);
      expect(result, hasLength(1));
      // Should prefer truehd over atmos
      expect(result[0], PassthroughCodec.truehd);
    });

    test('handles empty list', () {
      final result = PassthroughCodec.fromMpvValues([]);
      expect(result, isEmpty);
    });
  });

  group('PassthroughCodec — toMpvValues', () {
    test('converts codecs to mpv strings', () {
      final result = PassthroughCodec.toMpvValues([
        PassthroughCodec.ac3,
        PassthroughCodec.dts,
      ]);
      expect(result, containsAll(['ac3', 'dts']));
    });

    test('deduplicates shared mpv values '
        '(atmos + truehd)', () {
      final result = PassthroughCodec.toMpvValues([
        PassthroughCodec.truehd,
        PassthroughCodec.atmos,
      ]);
      // Both map to 'truehd' — should deduplicate
      expect(result, hasLength(1));
      expect(result[0], 'truehd');
    });

    test('handles empty list', () {
      final result = PassthroughCodec.toMpvValues([]);
      expect(result, isEmpty);
    });
  });

  group('PassthroughCodec — preset lists', () {
    test('defaultCodecs has ac3 and dts', () {
      final defaults = PassthroughCodec.defaultCodecs;
      expect(defaults, hasLength(2));
      expect(defaults, contains(PassthroughCodec.ac3));
      expect(defaults, contains(PassthroughCodec.dts));
    });

    test('losslessCodecs has truehd and dtsHd', () {
      final lossless = PassthroughCodec.losslessCodecs;
      expect(lossless, hasLength(2));
      expect(lossless, contains(PassthroughCodec.truehd));
      expect(lossless, contains(PassthroughCodec.dtsHd));
    });

    test('dolbyCodecs has 4 Dolby entries', () {
      expect(PassthroughCodec.dolbyCodecs, hasLength(4));
    });

    test('dtsCodecs has 3 DTS entries', () {
      expect(PassthroughCodec.dtsCodecs, hasLength(3));
    });
  });
}
