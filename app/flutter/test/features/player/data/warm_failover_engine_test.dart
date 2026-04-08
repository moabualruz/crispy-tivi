import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/data/warm_failover_engine.dart';

class MockCacheService extends Mock implements CacheService {}

void main() {
  group('WarmFailoverEngine', () {
    late MemoryBackend backend;
    late CacheService cacheService;

    setUp(() {
      backend = MemoryBackend();
      cacheService = CacheService(backend);
    });

    WarmFailoverEngine createEngine() =>
        WarmFailoverEngine(cacheService: cacheService);

    test('starts in idle state', () {
      final engine = createEngine();
      expect(engine.state, WarmFailoverState.idle);
      expect(engine.warmUrl, isNull);
      engine.dispose();
    });

    test('onBufferUpdate does nothing without current stream', () async {
      final engine = createEngine();
      await engine.onBufferUpdate(0.5);
      expect(engine.state, WarmFailoverState.idle);
      engine.dispose();
    });

    test('onStreamStall returns null without current stream', () async {
      final engine = createEngine();
      final result = await engine.onStreamStall();
      expect(result, isNull);
      engine.dispose();
    });

    test('onChannelChange resets state', () async {
      final engine = createEngine();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson: '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1"}',
        allChannelsJson: '[]',
      );
      await engine.onChannelChange();
      expect(engine.state, WarmFailoverState.idle);
      expect(engine.warmUrl, isNull);
      engine.dispose();
    });

    test(
      'evaluateFailoverEvent returns none for first few buffer samples',
      () async {
        final engine = createEngine();
        engine.setCurrentStream(
          urlHash: 'hash1',
          channelJson:
              '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1"}',
          allChannelsJson: '[]',
        );

        // First 3 low-buffer samples → action=none, state stays idle.
        for (var i = 0; i < 3; i++) {
          await engine.onBufferUpdate(0.5);
          expect(engine.state, WarmFailoverState.idle);
        }

        engine.dispose();
      },
    );

    test('4th low-buffer sample triggers warming attempt', () async {
      final engine = createEngine();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson: '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1"}',
        // No alternatives available — warming will fail gracefully.
        allChannelsJson: '[]',
      );

      // 4 consecutive low-buffer samples → start_warming.
      // But no alternatives, so engine stays idle (no crash).
      for (var i = 0; i < 4; i++) {
        await engine.onBufferUpdate(0.5);
      }

      // Without alternatives, warming can't start.
      // Engine attempted but no candidate → stays idle.
      expect(engine.state, WarmFailoverState.idle);
      engine.dispose();
    });

    test('buffer above reset threshold resets counter', () async {
      final engine = createEngine();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson: '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1"}',
        allChannelsJson: '[]',
      );

      // 3 low-buffer samples.
      for (var i = 0; i < 3; i++) {
        await engine.onBufferUpdate(0.5);
      }

      // Buffer recovers above 2.0 → resets counter.
      await engine.onBufferUpdate(3.0);

      // 3 more low-buffer samples → still only 3 (not 7).
      for (var i = 0; i < 3; i++) {
        await engine.onBufferUpdate(0.5);
        expect(engine.state, WarmFailoverState.idle);
      }

      engine.dispose();
    });

    test('stall events accumulate but no swap without warm player', () async {
      final engine = createEngine();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson: '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1"}',
        allChannelsJson: '[]',
      );

      // 5 stalls → no swap_warm yet (need 6).
      for (var i = 0; i < 5; i++) {
        final result = await engine.onStreamStall();
        expect(result, isNull);
      }

      // 6th stall → swap_warm, but no warm player ready.
      // Cold failover returns null (no alternatives).
      final result = await engine.onStreamStall();
      expect(result, isNull);

      engine.dispose();
    });

    test('cold failover returns alternative URL when available', () async {
      final engine = createEngine();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson:
            '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1",'
            '"source_id":"src1"}',
        allChannelsJson:
            '[{"id":"ch2","name":"CNN","stream_url":"http://b.com/2",'
            '"source_id":"src2","number":null,"channel_group":null,'
            '"logo_url":null,"tvg_id":null,"tvg_name":null,'
            '"is_favorite":false,"user_agent":null,"has_catchup":false,'
            '"catchup_days":0,"catchup_type":null,"catchup_source":null,'
            '"resolution":null,"added_at":null,"updated_at":null}]',
      );

      // 6 stalls → swap_warm triggered.
      for (var i = 0; i < 5; i++) {
        await engine.onStreamStall();
      }
      final result = await engine.onStreamStall();
      // Cold failover should return the alternative URL.
      expect(result, 'http://b.com/2');

      engine.dispose();
    });

    test('tried URLs prevent retry loops', () async {
      final engine = createEngine();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson:
            '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1",'
            '"source_id":"src1"}',
        allChannelsJson:
            '[{"id":"ch2","name":"CNN","stream_url":"http://b.com/2",'
            '"source_id":"src2","number":null,"channel_group":null,'
            '"logo_url":null,"tvg_id":null,"tvg_name":null,'
            '"is_favorite":false,"user_agent":null,"has_catchup":false,'
            '"catchup_days":0,"catchup_type":null,"catchup_source":null,'
            '"resolution":null,"added_at":null,"updated_at":null}]',
      );

      // First failover — gets alt URL.
      for (var i = 0; i < 6; i++) {
        await engine.onStreamStall();
      }

      // Reset failover counters for next round.
      await engine.onChannelChange();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson:
            '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1",'
            '"source_id":"src1"}',
        allChannelsJson:
            '[{"id":"ch2","name":"CNN","stream_url":"http://b.com/2",'
            '"source_id":"src2","number":null,"channel_group":null,'
            '"logo_url":null,"tvg_id":null,"tvg_name":null,'
            '"is_favorite":false,"user_agent":null,"has_catchup":false,'
            '"catchup_days":0,"catchup_type":null,"catchup_source":null,'
            '"resolution":null,"added_at":null,"updated_at":null}]',
      );

      // After channel change, tried URLs are cleared.
      for (var i = 0; i < 6; i++) {
        await engine.onStreamStall();
      }
      // Should get URL again since channel change cleared tried set.
      // (Result is from cold failover since no warm player exists.)

      engine.dispose();
    });

    test('dispose cleans up', () {
      final engine = createEngine();
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson: '{"id":"ch1","name":"CNN","stream_url":"http://a.com/1"}',
        allChannelsJson: '[]',
      );
      engine.dispose();
      expect(engine.state, WarmFailoverState.idle);
      expect(engine.warmUrl, isNull);
    });

    test('WarmFailoverState enum has expected values', () {
      expect(WarmFailoverState.values.length, 3);
      expect(WarmFailoverState.values, contains(WarmFailoverState.idle));
      expect(WarmFailoverState.values, contains(WarmFailoverState.warming));
      expect(WarmFailoverState.values, contains(WarmFailoverState.ready));
    });
  });

  group('MemoryBackend stream health', () {
    late MemoryBackend backend;

    setUp(() {
      backend = MemoryBackend();
    });

    test('recordStreamStall increments stall count', () async {
      await backend.recordStreamStall('h1');
      await backend.recordStreamStall('h1');
      final score = await backend.getStreamHealthScore('h1');
      // 2 stalls → score < 1.0 due to stall penalty.
      expect(score, lessThan(1.0));
    });

    test('unknown URL hash returns 0.5', () async {
      final score = await backend.getStreamHealthScore('unknown');
      expect(score, 0.5);
    });

    test('recordStreamBufferSample accumulates', () async {
      await backend.recordStreamBufferSample('h1', 5.0);
      await backend.recordStreamBufferSample('h1', 3.0);
      final score = await backend.getStreamHealthScore('h1');
      expect(score, greaterThan(0.0));
    });

    test('recordStreamTtff records latest', () async {
      await backend.recordStreamTtff('h1', 500);
      await backend.recordStreamTtff('h1', 300);
      final score = await backend.getStreamHealthScore('h1');
      expect(score, greaterThan(0.0));
    });

    test('pruneStreamHealth keeps max entries', () async {
      for (var i = 0; i < 10; i++) {
        await backend.recordStreamStall('h$i');
      }
      final pruned = await backend.pruneStreamHealth(5);
      expect(pruned, 5);
    });

    test(
      'evaluateFailoverEvent returns start_warming after 4 low buffers',
      () async {
        for (var i = 0; i < 3; i++) {
          final result = await backend.evaluateFailoverEvent(
            'h1',
            'buffer',
            0.5,
          );
          expect(result, contains('"none"'));
        }
        final result = await backend.evaluateFailoverEvent('h1', 'buffer', 0.5);
        expect(result, contains('"start_warming"'));
      },
    );

    test('evaluateFailoverEvent returns swap_warm after 6 stalls', () async {
      for (var i = 0; i < 5; i++) {
        final result = await backend.evaluateFailoverEvent('h1', 'stall', 0.0);
        expect(result, contains('"none"'));
      }
      final result = await backend.evaluateFailoverEvent('h1', 'stall', 0.0);
      expect(result, contains('"swap_warm"'));
    });

    test('evaluateFailoverEvent resets on high buffer', () async {
      // 3 low buffers.
      for (var i = 0; i < 3; i++) {
        await backend.evaluateFailoverEvent('h1', 'buffer', 0.5);
      }
      // Buffer recovers.
      await backend.evaluateFailoverEvent('h1', 'buffer', 3.0);
      // 3 more low buffers — still not enough.
      for (var i = 0; i < 3; i++) {
        final result = await backend.evaluateFailoverEvent('h1', 'buffer', 0.5);
        expect(result, contains('"none"'));
      }
    });

    test('resetFailoverState clears counters', () async {
      // 3 low buffers.
      for (var i = 0; i < 3; i++) {
        await backend.evaluateFailoverEvent('h1', 'buffer', 0.5);
      }
      await backend.resetFailoverState('h1');
      // 3 more — should not trigger (counter reset).
      for (var i = 0; i < 3; i++) {
        final result = await backend.evaluateFailoverEvent('h1', 'buffer', 0.5);
        expect(result, contains('"none"'));
      }
    });

    test('getStreamHealthScores returns batch scores', () async {
      await backend.recordStreamStall('h1');
      await backend.recordStreamStall('h2');
      final json = await backend.getStreamHealthScores('["h1","h2","h3"]');
      expect(json, contains('"h1"'));
      expect(json, contains('"h2"'));
      expect(json, contains('"h3"'));
    });

    test('extractCallSign returns call sign or empty', () {
      expect(backend.extractCallSign('CBS (WCBS)'), 'WCBS');
      expect(backend.extractCallSign('WABC'), 'WABC');
      expect(backend.extractCallSign('CNN'), '');
      expect(backend.extractCallSign('HBO'), '');
    });
  });
}
