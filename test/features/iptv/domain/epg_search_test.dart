import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:crispy_tivi/features/iptv/domain/utils/epg_search.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

Channel _ch(String id, {String? tvgId}) => Channel(
  id: id,
  name: 'Channel $id',
  streamUrl: 'http://stream/$id',
  tvgId: tvgId,
);

EpgEntry _entry(
  String channelId,
  String title, {
  required DateTime start,
  required DateTime end,
}) => EpgEntry(
  channelId: channelId,
  title: title,
  startTime: start,
  endTime: end,
);

// ── channelIdsWithMatchingLiveProgram ──────────────────────────────────────

void main() {
  final now = DateTime(2024, 1, 1, 12, 0);
  final before = now.subtract(const Duration(hours: 1));
  final after = now.add(const Duration(hours: 1));

  group('channelIdsWithMatchingLiveProgram', () {
    test('returns ids of channels with matching live program', () {
      final entries = {
        'ch1': [_entry('ch1', 'News Hour', start: before, end: after)],
        'ch2': [_entry('ch2', 'Sports', start: before, end: after)],
      };
      final result = channelIdsWithMatchingLiveProgram(
        entries,
        'news',
        now: now,
      );
      expect(result, contains('ch1'));
      expect(result, isNot(contains('ch2')));
    });

    test('returns empty set when no program matches', () {
      final entries = {
        'ch1': [_entry('ch1', 'Sports Live', start: before, end: after)],
      };
      final result = channelIdsWithMatchingLiveProgram(
        entries,
        'news',
        now: now,
      );
      expect(result, isEmpty);
    });

    test('is case insensitive', () {
      final entries = {
        'ch1': [_entry('ch1', 'BBC NEWS', start: before, end: after)],
      };
      final result = channelIdsWithMatchingLiveProgram(
        entries,
        'bbc news',
        now: now,
      );
      expect(result, contains('ch1'));
    });
  });

  // ── mergeEpgMatchedChannels ────────────────────────────────────────────────

  group('mergeEpgMatchedChannels', () {
    final chA = _ch('A');
    final chB = _ch('B');
    final chC = _ch('C');

    test('returns baseList unchanged when no extras match', () {
      final result = mergeEpgMatchedChannels(
        [chA],
        [chA, chB, chC],
        {'X'}, // none of A/B/C is in matchIds
        {},
      );
      expect(result, [chA]);
    });

    test('appends EPG-matched channels not already in baseList', () {
      final result = mergeEpgMatchedChannels(
        [chA],
        [chA, chB, chC],
        {'B'}, // chB matches by id
        {},
      );
      expect(result, [chA, chB]);
    });

    test('does not duplicate channels already in baseList', () {
      final result = mergeEpgMatchedChannels(
        [chA, chB],
        [chA, chB, chC],
        {'A', 'B'}, // both already in baseList
        {},
      );
      expect(result.length, 2);
    });

    test('resolves match via epgOverrides', () {
      // chB has no tvgId but an override maps B → epg_b
      final result = mergeEpgMatchedChannels(
        [chA],
        [chA, chB],
        {'epg_b'},
        {'B': 'epg_b'},
      );
      expect(result, contains(chB));
    });

    test('resolves match via tvgId', () {
      final chBWithTvg = _ch('B', tvgId: 'tvg_b');
      final result = mergeEpgMatchedChannels([chA], [chA, chBWithTvg], {
        'tvg_b',
      }, {});
      expect(result, contains(chBWithTvg));
    });

    test('returns baseList when all channels already present', () {
      final result = mergeEpgMatchedChannels([chA, chB, chC], [chA, chB, chC], {
        'A',
        'B',
        'C',
      }, {});
      expect(result.length, 3);
    });

    test('returns empty list when both inputs are empty', () {
      final result = mergeEpgMatchedChannels([], [], {}, {});
      expect(result, isEmpty);
    });

    test('appends multiple extras in allChannels order', () {
      final result = mergeEpgMatchedChannels(
        [],
        [chA, chB, chC],
        {'A', 'C'},
        {},
      );
      expect(result, [chA, chC]);
    });
  });
}
