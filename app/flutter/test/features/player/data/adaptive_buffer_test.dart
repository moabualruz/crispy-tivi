import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/features/player/data/adaptive_buffer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCacheService extends Mock implements CacheService {}

void main() {
  late MockCacheService mockCache;
  late AdaptiveBufferManager manager;

  setUp(() {
    mockCache = MockCacheService();
    manager = AdaptiveBufferManager(cacheService: mockCache);
  });

  group('BufferTier', () {
    test('readahead seconds are correct', () {
      expect(BufferTier.fast.readaheadSecs, 60);
      expect(BufferTier.normal.readaheadSecs, 120);
      expect(BufferTier.aggressive.readaheadSecs, 180);
    });

    test('fromName parses valid names', () {
      expect(BufferTier.fromName('fast'), BufferTier.fast);
      expect(BufferTier.fromName('normal'), BufferTier.normal);
      expect(BufferTier.fromName('aggressive'), BufferTier.aggressive);
    });

    test('fromName defaults to normal for unknown', () {
      expect(BufferTier.fromName('unknown'), BufferTier.normal);
      expect(BufferTier.fromName(''), BufferTier.normal);
    });
  });

  group('hashUrl', () {
    test('returns hex string', () {
      final hash = AdaptiveBufferManager.hashUrl('http://example.com/stream');
      expect(hash, isNotEmpty);
      expect(hash, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('same URL produces same hash', () {
      const url = 'http://example.com/stream';
      expect(
        AdaptiveBufferManager.hashUrl(url),
        AdaptiveBufferManager.hashUrl(url),
      );
    });

    test('different URLs produce different hashes', () {
      final h1 = AdaptiveBufferManager.hashUrl('http://a.com');
      final h2 = AdaptiveBufferManager.hashUrl('http://b.com');
      expect(h1, isNot(h2));
    });
  });

  group('init', () {
    test('prunes old entries', () async {
      when(() => mockCache.pruneBufferTiers(200)).thenAnswer((_) async => 5);

      await manager.init();

      verify(() => mockCache.pruneBufferTiers(200)).called(1);
    });
  });

  group('getTierForUrl', () {
    test('returns persisted tier', () async {
      when(
        () => mockCache.getBufferTier(any()),
      ).thenAnswer((_) async => 'aggressive');

      final tier = await manager.getTierForUrl('http://stream.com/live');
      expect(tier, BufferTier.aggressive);
      expect(manager.currentTier, BufferTier.aggressive);
    });

    test('defaults to normal when no persisted tier', () async {
      when(() => mockCache.getBufferTier(any())).thenAnswer((_) async => null);

      final tier = await manager.getTierForUrl('http://stream.com/live');
      expect(tier, BufferTier.normal);
    });
  });

  group('onBufferUpdate', () {
    test('returns null when no change', () async {
      when(() => mockCache.evaluateBufferSample(any(), any())).thenAnswer(
        (_) async => '{"tier":"normal","changed":false,"readahead_secs":120}',
      );

      final result = await manager.onBufferUpdate('http://x.com', 3.0);
      expect(result, isNull);
      expect(manager.currentTier, BufferTier.normal);
    });

    test('returns new tier when changed', () async {
      when(() => mockCache.evaluateBufferSample(any(), any())).thenAnswer(
        (_) async =>
            '{"tier":"aggressive","changed":true,"readahead_secs":180}',
      );

      final result = await manager.onBufferUpdate('http://x.com', 0.5);
      expect(result, BufferTier.aggressive);
      expect(manager.currentTier, BufferTier.aggressive);
    });

    test('handles parse error gracefully', () async {
      when(
        () => mockCache.evaluateBufferSample(any(), any()),
      ).thenAnswer((_) async => 'invalid json');

      final result = await manager.onBufferUpdate('http://x.com', 1.0);
      expect(result, isNull);
    });
  });

  group('mpvOptionsForTier', () {
    test('includes cache and readahead for all tiers', () {
      for (final tier in BufferTier.values) {
        final opts = AdaptiveBufferManager.mpvOptionsForTier(tier);
        expect(opts['cache'], 'yes');
        expect(opts['cache-pause'], 'no');
        expect(opts['cache-pause-initial'], 'no');
        expect(opts['cache-pause-wait'], '0');
        expect(opts['demuxer-readahead-secs'], tier.readaheadSecs.toString());
      }
    });

    test('includes buffer cap when provided', () {
      final opts = AdaptiveBufferManager.mpvOptionsForTier(
        BufferTier.normal,
        bufferCapMb: 64,
      );
      expect(opts['demuxer-max-bytes'], '64M');
    });

    test('omits buffer cap when not provided', () {
      final opts = AdaptiveBufferManager.mpvOptionsForTier(BufferTier.normal);
      expect(opts.containsKey('demuxer-max-bytes'), isFalse);
    });
  });

  group('onChannelChange', () {
    test('resets state and loads tier for new URL', () async {
      when(() => mockCache.resetBufferState(any())).thenAnswer((_) async {});
      when(
        () => mockCache.getBufferTier(any()),
      ).thenAnswer((_) async => 'fast');

      final tier = await manager.onChannelChange('http://new-channel.com');
      expect(tier, BufferTier.fast);
      verify(() => mockCache.resetBufferState(any())).called(1);
      verify(() => mockCache.getBufferTier(any())).called(1);
    });

    test('defaults to normal when new channel has no tier', () async {
      when(() => mockCache.resetBufferState(any())).thenAnswer((_) async {});
      when(() => mockCache.getBufferTier(any())).thenAnswer((_) async => null);

      final tier = await manager.onChannelChange('http://fresh-channel.com');
      expect(tier, BufferTier.normal);
    });
  });
}
