import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'stream_profile.dart';

void main() {
  group('StreamProfile', () {
    test('auto profile has null maxBitrateKbps', () {
      expect(StreamProfile.auto.maxBitrateKbps, isNull);
    });

    test('maximum profile has null maxBitrateKbps', () {
      expect(StreamProfile.maximum.maxBitrateKbps, isNull);
    });

    test('low profile has 1000 Kbps', () {
      expect(StreamProfile.low.maxBitrateKbps, 1000);
    });

    test('medium profile has 3000 Kbps', () {
      expect(StreamProfile.medium.maxBitrateKbps, 3000);
    });

    test('high profile has 8000 Kbps', () {
      expect(StreamProfile.high.maxBitrateKbps, 8000);
    });

    test('all profiles have non-empty labels', () {
      for (final p in StreamProfile.values) {
        expect(p.label, isNotEmpty);
      }
    });

    test('all profiles have non-empty descriptions', () {
      for (final p in StreamProfile.values) {
        expect(p.description, isNotEmpty);
      }
    });
  });

  group('StreamProfile — mpvHlsBitrate', () {
    test('auto returns "no"', () {
      expect(StreamProfile.auto.mpvHlsBitrate, 'no');
    });

    test('maximum returns "max"', () {
      expect(StreamProfile.maximum.mpvHlsBitrate, 'max');
    });

    test('low returns bitrate in bps string', () {
      expect(StreamProfile.low.mpvHlsBitrate, '1000000');
    });

    test('medium returns bitrate in bps string', () {
      expect(StreamProfile.medium.mpvHlsBitrate, '3000000');
    });

    test('high returns bitrate in bps string', () {
      expect(StreamProfile.high.mpvHlsBitrate, '8000000');
    });
  });

  group('StreamProfile — hlsJsBandwidthLimit', () {
    test('auto returns null (no limit)', () {
      expect(StreamProfile.auto.hlsJsBandwidthLimit, isNull);
    });

    test('maximum returns null (no limit)', () {
      expect(StreamProfile.maximum.hlsJsBandwidthLimit, isNull);
    });

    test('low returns 1000000 bps', () {
      expect(StreamProfile.low.hlsJsBandwidthLimit, 1000000);
    });

    test('medium returns 3000000 bps', () {
      expect(StreamProfile.medium.hlsJsBandwidthLimit, 3000000);
    });

    test('high returns 8000000 bps', () {
      expect(StreamProfile.high.hlsJsBandwidthLimit, 8000000);
    });
  });
}
