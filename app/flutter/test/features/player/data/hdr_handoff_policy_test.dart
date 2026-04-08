import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/data/hdr_handoff_policy.dart';

void main() {
  group('HdrHandoffPolicy', () {
    test('shouldHandoff returns false when device does not support HDR', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: false,
        supportedFormats: ['hdr10'],
      );
      expect(policy.shouldHandoff(VideoFormat.hdr10), isFalse);
    });

    test('shouldHandoff returns false for SDR content', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: ['hdr10', 'hlg'],
      );
      expect(policy.shouldHandoff(VideoFormat.sdr), isFalse);
    });

    test('shouldHandoff returns false for null format', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: ['hdr10'],
      );
      expect(policy.shouldHandoff(null), isFalse);
    });

    test('shouldHandoff returns true for HDR10 on capable device', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: ['hdr10', 'hlg'],
      );
      expect(policy.shouldHandoff(VideoFormat.hdr10), isTrue);
    });

    test('shouldHandoff returns true for HLG on capable device', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: ['hdr10', 'hlg'],
      );
      expect(policy.shouldHandoff(VideoFormat.hlg), isTrue);
    });

    test(
      'shouldHandoff returns false for DolbyVision when only HDR10 supported',
      () {
        final policy = HdrHandoffPolicy.withState(
          deviceSupportsHdr: true,
          supportedFormats: ['hdr10'],
        );
        expect(policy.shouldHandoff(VideoFormat.dolbyVision), isFalse);
      },
    );

    test('shouldHandoff returns true for DolbyVision when supported', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: ['hdr10', 'dolby_vision'],
      );
      expect(policy.shouldHandoff(VideoFormat.dolbyVision), isTrue);
    });

    test('shouldHandoff returns true for HDR10Plus when supported', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: ['hdr10_plus'],
      );
      expect(policy.shouldHandoff(VideoFormat.hdr10Plus), isTrue);
    });

    test(
      'shouldHandoff returns true for generic HDR when any format supported',
      () {
        final policy = HdrHandoffPolicy.withState(
          deviceSupportsHdr: true,
          supportedFormats: ['hlg'],
        );
        expect(policy.shouldHandoff(VideoFormat.hdr), isTrue);
      },
    );

    test(
      'shouldHandoff returns false for generic HDR when no formats supported',
      () {
        final policy = HdrHandoffPolicy.withState(
          deviceSupportsHdr: true,
          supportedFormats: [],
        );
        expect(policy.shouldHandoff(VideoFormat.hdr), isFalse);
      },
    );

    test('isInitialized is false before init', () {
      final policy = HdrHandoffPolicy();
      expect(policy.isInitialized, isFalse);
    });

    test('isInitialized is true after withState constructor', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: false,
        supportedFormats: [],
      );
      expect(policy.isInitialized, isTrue);
    });

    test('deviceSupportsHdr reflects constructor state', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: [],
      );
      expect(policy.deviceSupportsHdr, isTrue);
    });

    test('supportedFormats returns unmodifiable list', () {
      final policy = HdrHandoffPolicy.withState(
        deviceSupportsHdr: true,
        supportedFormats: ['hdr10'],
      );
      expect(
        () => policy.supportedFormats.add('hlg'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
