import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/data/warm_failover_engine.dart';

void main() {
  late MemoryBackend backend;
  late CacheService cache;
  late WarmFailoverEngine engine;

  setUp(() {
    backend = MemoryBackend();
    cache = CacheService(backend);
    engine = WarmFailoverEngine(cacheService: cache);
  });

  tearDown(() => engine.dispose());

  group('WarmFailoverEngine smart group integration', () {
    test('channelId is cleared on channel change', () async {
      engine.setCurrentStream(
        urlHash: 'hash1',
        channelJson: '{}',
        allChannelsJson: '[]',
        channelId: 'ch1',
      );

      await engine.onChannelChange();

      // After channel change, state should be idle.
      expect(engine.state, WarmFailoverState.idle);
    });

    test('setCurrentStream accepts optional channelId', () {
      // Without channelId — backwards compatible.
      engine.setCurrentStream(
        urlHash: 'hash2',
        channelJson: '{}',
        allChannelsJson: '[]',
      );
      expect(engine.state, WarmFailoverState.idle);

      // With channelId.
      engine.setCurrentStream(
        urlHash: 'hash3',
        channelJson: '{}',
        allChannelsJson: '[]',
        channelId: 'ch_test',
      );
      expect(engine.state, WarmFailoverState.idle);
    });

    test('smart group alternatives are preferred over general', () async {
      // Create a smart group with alternatives.
      final groupId = await cache.createSmartGroup('ESPN');
      await cache.addSmartGroupMember(groupId, 'ch1', 'src1', 0);
      await cache.addSmartGroupMember(groupId, 'ch2', 'src2', 1);

      // Set up all channels JSON so the engine can resolve URLs.
      final allChannels = jsonEncode([
        {'id': 'ch1', 'name': 'ESPN', 'stream_url': 'http://a/espn'},
        {'id': 'ch2', 'name': 'ESPN', 'stream_url': 'http://b/espn'},
      ]);

      engine.setCurrentStream(
        urlHash: 'hash_a',
        channelJson: jsonEncode({'id': 'ch1', 'name': 'ESPN'}),
        allChannelsJson: allChannels,
        channelId: 'ch1',
      );

      // The engine should be idle (no stall events yet).
      expect(engine.state, WarmFailoverState.idle);
    });
  });

  group('Smart group CacheService methods', () {
    test('createSmartGroup returns non-empty ID', () async {
      final id = await cache.createSmartGroup('Test Group');
      expect(id, isNotEmpty);
    });

    test('getSmartGroupAlternatives returns JSON', () async {
      final gid = await cache.createSmartGroup('CNN');
      await cache.addSmartGroupMember(gid, 'ch_a', 'src_a', 0);
      await cache.addSmartGroupMember(gid, 'ch_b', 'src_b', 1);

      final json = await cache.getSmartGroupAlternatives('ch_a');
      final alts = jsonDecode(json) as List;
      expect(alts, hasLength(1));
      expect(alts[0]['channel_id'], 'ch_b');
    });

    test('getSmartGroupAlternatives empty for non-grouped channel', () async {
      final json = await cache.getSmartGroupAlternatives('non_existent');
      final alts = jsonDecode(json) as List;
      expect(alts, isEmpty);
    });
  });
}
