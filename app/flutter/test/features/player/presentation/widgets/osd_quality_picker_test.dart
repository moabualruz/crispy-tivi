import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/domain/entities/stream_profile.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_settings_providers.dart';

void main() {
  group('RuntimeStreamProfileNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial value is auto', () {
      final profile = container.read(runtimeStreamProfileProvider);
      expect(profile, StreamProfile.auto);
    });

    test('set updates profile', () {
      final notifier = container.read(runtimeStreamProfileProvider.notifier);

      notifier.set(StreamProfile.high);
      expect(container.read(runtimeStreamProfileProvider), StreamProfile.high);
    });

    test('set to low updates profile', () {
      final notifier = container.read(runtimeStreamProfileProvider.notifier);

      notifier.set(StreamProfile.low);
      expect(container.read(runtimeStreamProfileProvider), StreamProfile.low);
    });

    test('set back to auto', () {
      final notifier = container.read(runtimeStreamProfileProvider.notifier);

      notifier.set(StreamProfile.maximum);
      expect(
        container.read(runtimeStreamProfileProvider),
        StreamProfile.maximum,
      );

      notifier.set(StreamProfile.auto);
      expect(container.read(runtimeStreamProfileProvider), StreamProfile.auto);
    });
  });

  group('StreamProfile', () {
    test('all profiles have labels', () {
      for (final profile in StreamProfile.values) {
        expect(profile.label, isNotEmpty);
        expect(profile.description, isNotEmpty);
      }
    });

    test('auto profile has no bitrate limit', () {
      expect(StreamProfile.auto.maxBitrateKbps, isNull);
    });

    test('maximum profile has no bitrate limit', () {
      expect(StreamProfile.maximum.maxBitrateKbps, isNull);
    });

    test('low/medium/high have correct bitrate values', () {
      expect(StreamProfile.low.maxBitrateKbps, 1000);
      expect(StreamProfile.medium.maxBitrateKbps, 3000);
      expect(StreamProfile.high.maxBitrateKbps, 8000);
    });

    test('mpvHlsBitrate returns correct values', () {
      expect(StreamProfile.auto.mpvHlsBitrate, 'no');
      expect(StreamProfile.low.mpvHlsBitrate, '1000000');
      expect(StreamProfile.medium.mpvHlsBitrate, '3000000');
      expect(StreamProfile.high.mpvHlsBitrate, '8000000');
      expect(StreamProfile.maximum.mpvHlsBitrate, 'max');
    });

    test('hlsJsBandwidthLimit returns correct values', () {
      expect(StreamProfile.auto.hlsJsBandwidthLimit, isNull);
      expect(StreamProfile.low.hlsJsBandwidthLimit, 1000000);
      expect(StreamProfile.medium.hlsJsBandwidthLimit, 3000000);
      expect(StreamProfile.high.hlsJsBandwidthLimit, 8000000);
      expect(StreamProfile.maximum.hlsJsBandwidthLimit, isNull);
    });

    test('enum has 5 values', () {
      expect(StreamProfile.values, hasLength(5));
    });
  });
}
