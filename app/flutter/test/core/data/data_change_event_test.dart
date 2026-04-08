import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/data_change_event.dart';

void main() {
  group('DataChangeEvent.fromJson', () {
    // ── Channels / Playlists ─────────────────────────────────

    test('ChannelsUpdated — parses source_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"ChannelsUpdated","source_id":"src-42"}',
      );
      expect(event, isA<ChannelsUpdated>());
      expect((event as ChannelsUpdated).sourceId, 'src-42');
    });

    test('CategoriesUpdated — parses source_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"CategoriesUpdated","source_id":"src-99"}',
      );
      expect(event, isA<CategoriesUpdated>());
      expect((event as CategoriesUpdated).sourceId, 'src-99');
    });

    test('ChannelOrderChanged — no extra fields', () {
      final event = DataChangeEvent.fromJson('{"type":"ChannelOrderChanged"}');
      expect(event, isA<ChannelOrderChanged>());
    });

    // ── EPG ──────────────────────────────────────────────────

    test('EpgUpdated — parses source_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"EpgUpdated","source_id":"epg-src-1"}',
      );
      expect(event, isA<EpgUpdated>());
      expect((event as EpgUpdated).sourceId, 'epg-src-1');
    });

    // ── Watch History ─────────────────────────────────────────

    test('WatchHistoryUpdated — parses channel_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"WatchHistoryUpdated","channel_id":"ch-77"}',
      );
      expect(event, isA<WatchHistoryUpdated>());
      expect((event as WatchHistoryUpdated).channelId, 'ch-77');
    });

    test('WatchHistoryCleared — no extra fields', () {
      final event = DataChangeEvent.fromJson('{"type":"WatchHistoryCleared"}');
      expect(event, isA<WatchHistoryCleared>());
    });

    // ── Favorites ─────────────────────────────────────────────

    test('FavoriteToggled — parses item_id and is_favorite true', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"FavoriteToggled","item_id":"ch1","is_favorite":true}',
      );
      expect(event, isA<FavoriteToggled>());
      final ft = event as FavoriteToggled;
      expect(ft.itemId, 'ch1');
      expect(ft.isFavorite, isTrue);
    });

    test('FavoriteToggled — parses is_favorite false', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"FavoriteToggled","item_id":"ch2","is_favorite":false}',
      );
      expect((event as FavoriteToggled).isFavorite, isFalse);
    });

    test(
      'FavoriteCategoryToggled — parses category_type and category_name',
      () {
        final event = DataChangeEvent.fromJson(
          '{"type":"FavoriteCategoryToggled",'
          '"category_type":"live","category_name":"Sports"}',
        );
        expect(event, isA<FavoriteCategoryToggled>());
        final fct = event as FavoriteCategoryToggled;
        expect(fct.categoryType, 'live');
        expect(fct.categoryName, 'Sports');
      },
    );

    // ── VOD ───────────────────────────────────────────────────

    test('VodUpdated — parses source_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"VodUpdated","source_id":"vod-src-3"}',
      );
      expect(event, isA<VodUpdated>());
      expect((event as VodUpdated).sourceId, 'vod-src-3');
    });

    test('VodFavoriteToggled — parses vod_id and is_favorite', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"VodFavoriteToggled","vod_id":"v99","is_favorite":true}',
      );
      expect(event, isA<VodFavoriteToggled>());
      final vft = event as VodFavoriteToggled;
      expect(vft.vodId, 'v99');
      expect(vft.isFavorite, isTrue);
    });

    test('VodWatchProgressUpdated — parses vod_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"VodWatchProgressUpdated","vod_id":"v123"}',
      );
      expect(event, isA<VodWatchProgressUpdated>());
      expect((event as VodWatchProgressUpdated).vodId, 'v123');
    });

    // ── Recordings / DVR ──────────────────────────────────────

    test('RecordingChanged — parses recording_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"RecordingChanged","recording_id":"rec-001"}',
      );
      expect(event, isA<RecordingChanged>());
      expect((event as RecordingChanged).recordingId, 'rec-001');
    });

    // ── Profiles ──────────────────────────────────────────────

    test('ProfileChanged — parses profile_id', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"ProfileChanged","profile_id":"prof-5"}',
      );
      expect(event, isA<ProfileChanged>());
      expect((event as ProfileChanged).profileId, 'prof-5');
    });

    // ── Settings ──────────────────────────────────────────────

    test('SettingsUpdated — parses key', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"SettingsUpdated","key":"theme"}',
      );
      expect(event, isA<SettingsUpdated>());
      expect((event as SettingsUpdated).key, 'theme');
    });

    // ── Misc UI data ──────────────────────────────────────────

    test('SavedLayoutChanged — no extra fields', () {
      final event = DataChangeEvent.fromJson('{"type":"SavedLayoutChanged"}');
      expect(event, isA<SavedLayoutChanged>());
    });

    test('SearchHistoryChanged — no extra fields', () {
      final event = DataChangeEvent.fromJson('{"type":"SearchHistoryChanged"}');
      expect(event, isA<SearchHistoryChanged>());
    });

    test('ReminderChanged — no extra fields', () {
      final event = DataChangeEvent.fromJson('{"type":"ReminderChanged"}');
      expect(event, isA<ReminderChanged>());
    });

    // ── Bulk ──────────────────────────────────────────────────

    test('CloudSyncCompleted — no extra fields', () {
      final event = DataChangeEvent.fromJson('{"type":"CloudSyncCompleted"}');
      expect(event, isA<CloudSyncCompleted>());
    });

    test('BulkDataRefresh — no extra fields', () {
      final event = DataChangeEvent.fromJson('{"type":"BulkDataRefresh"}');
      expect(event, isA<BulkDataRefresh>());
    });

    // ── Forward-compatibility ─────────────────────────────────

    test('unknown type returns UnknownEvent with type preserved', () {
      final event = DataChangeEvent.fromJson(
        '{"type":"NewFutureEventV2","some_field":"value"}',
      );
      expect(event, isA<UnknownEvent>());
      expect((event as UnknownEvent).type, 'NewFutureEventV2');
    });

    test('empty type field returns UnknownEvent with empty string', () {
      final event = DataChangeEvent.fromJson('{"type":""}');
      expect(event, isA<UnknownEvent>());
      expect((event as UnknownEvent).type, '');
    });

    test('missing type field (null) returns UnknownEvent', () {
      final event = DataChangeEvent.fromJson('{"other_field":"x"}');
      expect(event, isA<UnknownEvent>());
      expect((event as UnknownEvent).type, '');
    });

    test('malformed JSON throws FormatException', () {
      expect(
        () => DataChangeEvent.fromJson('{not valid json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('extra unknown fields are ignored for known types', () {
      // Forward-compatible: extra fields on known events should not throw.
      final event = DataChangeEvent.fromJson(
        '{"type":"BulkDataRefresh","extra_future_field":42}',
      );
      expect(event, isA<BulkDataRefresh>());
    });

    test('all 19 known event types parse without throwing', () {
      final fixtures = [
        '{"type":"ChannelsUpdated","source_id":"s"}',
        '{"type":"CategoriesUpdated","source_id":"s"}',
        '{"type":"ChannelOrderChanged"}',
        '{"type":"EpgUpdated","source_id":"s"}',
        '{"type":"WatchHistoryUpdated","channel_id":"c"}',
        '{"type":"WatchHistoryCleared"}',
        '{"type":"FavoriteToggled","item_id":"i","is_favorite":true}',
        '{"type":"FavoriteCategoryToggled",'
            '"category_type":"t","category_name":"n"}',
        '{"type":"VodUpdated","source_id":"s"}',
        '{"type":"VodFavoriteToggled","vod_id":"v","is_favorite":false}',
        '{"type":"VodWatchProgressUpdated","vod_id":"v"}',
        '{"type":"RecordingChanged","recording_id":"r"}',
        '{"type":"ProfileChanged","profile_id":"p"}',
        '{"type":"SettingsUpdated","key":"k"}',
        '{"type":"SavedLayoutChanged"}',
        '{"type":"SearchHistoryChanged"}',
        '{"type":"ReminderChanged"}',
        '{"type":"CloudSyncCompleted"}',
        '{"type":"BulkDataRefresh"}',
      ];

      expect(fixtures.length, 19);
      for (final json in fixtures) {
        expect(
          () => DataChangeEvent.fromJson(json),
          returnsNormally,
          reason: 'Should parse: $json',
        );
      }
    });
  });
}
