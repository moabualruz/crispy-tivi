import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/smart_group_providers.dart';

void main() {
  late MemoryBackend backend;
  late CacheService cache;

  setUp(() {
    backend = MemoryBackend();
    cache = CacheService(backend);
  });

  group('Smart group CRUD via CacheService', () {
    test('create and load groups', () async {
      final id = await cache.createSmartGroup('ESPN');
      expect(id, isNotEmpty);

      final json = await cache.getSmartGroupsJson();
      final groups = jsonDecode(json) as List;
      expect(groups, hasLength(1));
      expect(groups[0]['name'], 'ESPN');
    });

    test('rename group', () async {
      final id = await cache.createSmartGroup('CNN');
      await cache.renameSmartGroup(id, 'CNN International');

      final json = await cache.getSmartGroupsJson();
      final groups = jsonDecode(json) as List;
      expect(groups[0]['name'], 'CNN International');
    });

    test('delete group', () async {
      final id = await cache.createSmartGroup('Fox');
      await cache.deleteSmartGroup(id);

      final json = await cache.getSmartGroupsJson();
      final groups = jsonDecode(json) as List;
      expect(groups, isEmpty);
    });

    test('add and list members', () async {
      final id = await cache.createSmartGroup('BBC');
      await cache.addSmartGroupMember(id, 'ch1', 'src1', 0);
      await cache.addSmartGroupMember(id, 'ch2', 'src2', 1);

      final json = await cache.getSmartGroupsJson();
      final groups = jsonDecode(json) as List;
      final members = groups[0]['members'] as List;
      expect(members, hasLength(2));
      expect(members[0]['channel_id'], 'ch1');
      expect(members[1]['channel_id'], 'ch2');
    });

    test('remove member', () async {
      final id = await cache.createSmartGroup('ABC');
      await cache.addSmartGroupMember(id, 'ch1', 'src1', 0);
      await cache.addSmartGroupMember(id, 'ch2', 'src2', 1);
      await cache.removeSmartGroupMember(id, 'ch1');

      final json = await cache.getSmartGroupsJson();
      final groups = jsonDecode(json) as List;
      final members = groups[0]['members'] as List;
      expect(members, hasLength(1));
      expect(members[0]['channel_id'], 'ch2');
    });

    test('reorder members', () async {
      final id = await cache.createSmartGroup('NBC');
      await cache.addSmartGroupMember(id, 'ch1', 'src1', 0);
      await cache.addSmartGroupMember(id, 'ch2', 'src2', 1);
      await cache.addSmartGroupMember(id, 'ch3', 'src3', 2);

      await cache.reorderSmartGroupMembers(
        id,
        jsonEncode(['ch3', 'ch1', 'ch2']),
      );

      final json = await cache.getSmartGroupsJson();
      final groups = jsonDecode(json) as List;
      final members = groups[0]['members'] as List;
      // After reorder: ch3 (priority 0), ch1 (priority 1), ch2 (priority 2)
      expect(members[0]['channel_id'], 'ch3');
      expect(members[1]['channel_id'], 'ch1');
      expect(members[2]['channel_id'], 'ch2');
    });

    test('get smart group for channel', () async {
      final id = await cache.createSmartGroup('CBS');
      await cache.addSmartGroupMember(id, 'ch1', 'src1', 0);

      final result = await cache.getSmartGroupForChannel('ch1');
      expect(result, isNotNull);
      final group = jsonDecode(result!) as Map<String, dynamic>;
      expect(group['name'], 'CBS');

      final none = await cache.getSmartGroupForChannel('ch_unknown');
      expect(none, isNull);
    });

    test('get smart group alternatives excludes same source', () async {
      final id = await cache.createSmartGroup('ESPN');
      await cache.addSmartGroupMember(id, 'ch1', 'src1', 0);
      await cache.addSmartGroupMember(id, 'ch2', 'src2', 1);
      await cache.addSmartGroupMember(id, 'ch3', 'src1', 2);

      final json = await cache.getSmartGroupAlternatives('ch1');
      final alts = jsonDecode(json) as List;
      // ch2 (different source) should be included,
      // ch3 (same source as ch1) should be excluded.
      expect(alts, hasLength(1));
      expect(alts[0]['channel_id'], 'ch2');
    });
  });

  group('SmartGroup model parsing', () {
    test('SmartGroup.fromJson', () {
      final group = SmartGroup.fromJson({
        'id': 'g1',
        'name': 'Test',
        'members': [
          {'channel_id': 'c1', 'source_id': 's1', 'priority': 0},
          {'channel_id': 'c2', 'source_id': 's2', 'priority': 1},
        ],
      });

      expect(group.id, 'g1');
      expect(group.name, 'Test');
      expect(group.members, hasLength(2));
      expect(group.members[0].channelId, 'c1');
      expect(group.members[1].sourceId, 's2');
    });

    test('SmartGroupCandidate.fromJson', () {
      final candidate = SmartGroupCandidate.fromJson({
        'suggested_name': 'ESPN',
        'members': [
          {'channel_id': 'c1', 'source_id': 's1', 'channel_name': 'ESPN HD'},
        ],
      });

      expect(candidate.suggestedName, 'ESPN');
      expect(candidate.members, hasLength(1));
      expect(candidate.members[0].channelName, 'ESPN HD');
    });
  });

  group('Detect candidates', () {
    test('returns empty list from MemoryBackend', () async {
      final json = await cache.detectSmartGroupCandidates();
      final candidates = jsonDecode(json) as List;
      expect(candidates, isEmpty);
    });
  });
}
