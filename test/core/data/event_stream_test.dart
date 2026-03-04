import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/memory_backend.dart';

void main() {
  late MemoryBackend backend;

  setUp(() async {
    backend = MemoryBackend();
    await backend.init('');
  });

  group('MemoryBackend.dataEvents', () {
    test('delivers emitted events', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent(
        '{"type":"WatchHistoryUpdated","channel_id":"ch1"}',
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, contains('WatchHistoryUpdated'));
    });

    test('is a broadcast stream (multiple listeners)', () async {
      final a = <String>[];
      final b = <String>[];
      backend.dataEvents.listen(a.add);
      backend.dataEvents.listen(b.add);

      backend.emitTestEvent('{"type":"BulkDataRefresh"}');
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });

    test('delivers multiple events in order', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent(
        '{"type":"FavoriteToggled","item_id":"ch1","is_favorite":true}',
      );
      backend.emitTestEvent(
        '{"type":"FavoriteToggled","item_id":"ch2","is_favorite":false}',
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0], contains('"item_id":"ch1"'));
      expect(events[1], contains('"item_id":"ch2"'));
    });

    test('emits valid JSON', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent('{"type":"SettingsUpdated","key":"theme"}');
      await Future<void>.delayed(Duration.zero);

      final parsed = jsonDecode(events.first) as Map<String, dynamic>;
      expect(parsed['type'], 'SettingsUpdated');
      expect(parsed['key'], 'theme');
    });

    test('unit event variants have only type field', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      for (final type in [
        'WatchHistoryCleared',
        'SavedLayoutChanged',
        'SearchHistoryChanged',
        'ReminderChanged',
        'ChannelOrderChanged',
        'CloudSyncCompleted',
        'BulkDataRefresh',
      ]) {
        backend.emitTestEvent('{"type":"$type"}');
      }
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(7));
      for (final e in events) {
        final parsed = jsonDecode(e) as Map<String, dynamic>;
        expect(parsed.containsKey('type'), isTrue);
      }
    });

    test('no events before any emitTestEvent call', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });

    test('late listener does not receive old events', () async {
      backend.emitTestEvent('{"type":"BulkDataRefresh"}');
      await Future<void>.delayed(Duration.zero);

      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"s1"}');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, contains('ChannelsUpdated'));
    });

    test('VodFavoriteToggled carries vod_id and is_favorite', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent(
        '{"type":"VodFavoriteToggled","vod_id":"v99","is_favorite":true}',
      );
      await Future<void>.delayed(Duration.zero);

      final parsed = jsonDecode(events.first) as Map<String, dynamic>;
      expect(parsed['type'], 'VodFavoriteToggled');
      expect(parsed['vod_id'], 'v99');
      expect(parsed['is_favorite'], isTrue);
    });

    test('RecordingChanged carries recording_id', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent(
        '{"type":"RecordingChanged","recording_id":"rec1"}',
      );
      await Future<void>.delayed(Duration.zero);

      final parsed = jsonDecode(events.first) as Map<String, dynamic>;
      expect(parsed['recording_id'], 'rec1');
    });

    test('ProfileChanged carries profile_id', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent('{"type":"ProfileChanged","profile_id":"p1"}');
      await Future<void>.delayed(Duration.zero);

      final parsed = jsonDecode(events.first) as Map<String, dynamic>;
      expect(parsed['profile_id'], 'p1');
    });

    test('EpgUpdated carries source_id', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent('{"type":"EpgUpdated","source_id":"epg_src"}');
      await Future<void>.delayed(Duration.zero);

      final parsed = jsonDecode(events.first) as Map<String, dynamic>;
      expect(parsed['type'], 'EpgUpdated');
      expect(parsed['source_id'], 'epg_src');
    });

    test('FavoriteCategoryToggled carries type and name', () async {
      final events = <String>[];
      backend.dataEvents.listen(events.add);

      backend.emitTestEvent(
        '{"type":"FavoriteCategoryToggled","category_type":"live","category_name":"Sports"}',
      );
      await Future<void>.delayed(Duration.zero);

      final parsed = jsonDecode(events.first) as Map<String, dynamic>;
      expect(parsed['category_type'], 'live');
      expect(parsed['category_name'], 'Sports');
    });
  });
}
