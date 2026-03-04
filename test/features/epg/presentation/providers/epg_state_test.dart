import 'package:crispy_tivi/features/epg/'
    'presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/epg_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Helpers ─────────────────────────────────────

  DateTime utc(int y, int m, int d, [int h = 0, int min = 0]) =>
      DateTime.utc(y, m, d, h, min);

  Channel ch(String id, {String? group, String name = 'Ch'}) =>
      Channel(id: id, name: name, streamUrl: 'http://s/$id', group: group);

  EpgEntry entry(
    String channelId,
    String title,
    DateTime start,
    DateTime end,
  ) => EpgEntry(
    channelId: channelId,
    title: title,
    startTime: start,
    endTime: end,
  );

  // ── Default state ───────────────────────────────

  group('EpgState defaults', () {
    test('has empty channels and entries', () {
      const s = EpgState();
      expect(s.channels, isEmpty);
      expect(s.entries, isEmpty);
      expect(s.epgOverrides, isEmpty);
      expect(s.focusedTime, isNull);
      expect(s.selectedChannel, isNull);
      expect(s.selectedEntry, isNull);
      expect(s.selectedGroup, isNull);
      expect(s.showEpgOnly, isTrue);
      expect(s.viewMode, EpgViewMode.day);
      expect(s.isLoading, isFalse);
      expect(s.error, isNull);
      expect(s.lastFetchMessage, isNull);
      expect(s.lastFetchSuccess, isNull);
    });
  });

  // ── groups ──────────────────────────────────────

  group('groups', () {
    test('returns unique sorted group names', () {
      final s = EpgState(
        channels: [
          ch('1', group: 'Sports'),
          ch('2', group: 'News'),
          ch('3', group: 'Sports'),
          ch('4', group: 'Movies'),
        ],
      );
      expect(s.groups, ['Movies', 'News', 'Sports']);
    });

    test('excludes null and empty groups', () {
      final s = EpgState(
        channels: [
          ch('1', group: null),
          ch('2', group: ''),
          ch('3', group: 'News'),
        ],
      );
      expect(s.groups, ['News']);
    });

    test('returns empty when no groups', () {
      final s = EpgState(channels: [ch('1')]);
      expect(s.groups, isEmpty);
    });
  });

  // ── filteredChannels ────────────────────────────

  group('filteredChannels', () {
    test('returns all when no filters', () {
      final channels = [ch('1'), ch('2'), ch('3')];
      final s = EpgState(channels: channels, showEpgOnly: false);
      expect(s.filteredChannels, channels);
    });

    test('filters by selectedGroup', () {
      final s = EpgState(
        channels: [
          ch('1', group: 'Sports'),
          ch('2', group: 'News'),
          ch('3', group: 'Sports'),
        ],
        selectedGroup: 'Sports',
        showEpgOnly: false,
      );
      expect(s.filteredChannels.length, 2);
      expect(s.filteredChannels.every((c) => c.group == 'Sports'), isTrue);
    });

    test('filters by showEpgOnly', () {
      final entries = <String, List<EpgEntry>>{
        'ch1': [
          entry('ch1', 'Show', utc(2026, 2, 22, 10), utc(2026, 2, 22, 11)),
        ],
      };
      final s = EpgState(
        channels: [ch('ch1'), ch('ch2')],
        entries: entries,
        showEpgOnly: true,
      );
      expect(s.filteredChannels.length, 1);
      expect(s.filteredChannels.first.id, 'ch1');
    });

    test('showEpgOnly respects epgOverrides', () {
      // ch2 has no direct entries but is
      // overridden to ch1's entries.
      final entries = <String, List<EpgEntry>>{
        'ch1': [
          entry('ch1', 'Show', utc(2026, 2, 22, 10), utc(2026, 2, 22, 11)),
        ],
      };
      final s = EpgState(
        channels: [ch('ch1'), ch('ch2')],
        entries: entries,
        epgOverrides: {'ch2': 'ch1'},
        showEpgOnly: true,
      );
      expect(s.filteredChannels.length, 2);
    });

    test('combines group + showEpgOnly filters', () {
      final entries = <String, List<EpgEntry>>{
        'ch1': [entry('ch1', 'S', utc(2026, 2, 22, 10), utc(2026, 2, 22, 11))],
        'ch3': [entry('ch3', 'S', utc(2026, 2, 22, 10), utc(2026, 2, 22, 11))],
      };
      final s = EpgState(
        channels: [
          ch('ch1', group: 'News'),
          ch('ch2', group: 'News'),
          ch('ch3', group: 'Sports'),
        ],
        entries: entries,
        selectedGroup: 'News',
        showEpgOnly: true,
      );
      // Only ch1 is News AND has EPG data.
      expect(s.filteredChannels.length, 1);
      expect(s.filteredChannels.first.id, 'ch1');
    });
  });

  // ── entriesForChannel ───────────────────────────

  group('entriesForChannel', () {
    test('returns entries for channel', () {
      final e = entry(
        'ch1',
        'Show',
        utc(2026, 2, 22, 10),
        utc(2026, 2, 22, 11),
      );
      final s = EpgState(
        entries: {
          'ch1': [e],
        },
      );
      expect(s.entriesForChannel('ch1'), [e]);
    });

    test('returns empty list for unknown channel', () {
      final s = EpgState(
        entries: {
          'ch1': [
            entry('ch1', 'S', utc(2026, 2, 22, 10), utc(2026, 2, 22, 11)),
          ],
        },
      );
      expect(s.entriesForChannel('ch99'), isEmpty);
    });

    test('follows epgOverrides', () {
      final e = entry(
        'target',
        'Mapped',
        utc(2026, 2, 22, 10),
        utc(2026, 2, 22, 11),
      );
      final s = EpgState(
        entries: {
          'target': [e],
        },
        epgOverrides: {'ch2': 'target'},
      );
      expect(s.entriesForChannel('ch2'), [e]);
    });

    test('override target missing returns empty', () {
      final s = EpgState(epgOverrides: {'ch2': 'ghost'});
      expect(s.entriesForChannel('ch2'), isEmpty);
    });
  });

  // ── copyWith ────────────────────────────────────

  group('copyWith', () {
    test('copies all fields', () {
      final original = EpgState(
        channels: [ch('1')],
        entries: {
          'ch1': [
            entry('ch1', 'S', utc(2026, 2, 22, 10), utc(2026, 2, 22, 11)),
          ],
        },
        viewMode: EpgViewMode.day,
        isLoading: false,
      );
      final copy = original.copyWith(
        viewMode: EpgViewMode.week,
        isLoading: true,
      );
      expect(copy.viewMode, EpgViewMode.week);
      expect(copy.isLoading, isTrue);
      // Unchanged fields preserved.
      expect(copy.channels.length, 1);
    });

    test('clearGroup sets group to null', () {
      final s = EpgState(selectedGroup: 'News');
      final cleared = s.copyWith(clearGroup: true);
      expect(cleared.selectedGroup, isNull);
    });

    test('clearError sets error to null', () {
      final s = EpgState(error: 'fail');
      final cleared = s.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('clearSelectedEntry sets entry to null', () {
      final e = entry('ch1', 'S', utc(2026, 2, 22, 10), utc(2026, 2, 22, 11));
      final s = EpgState(selectedEntry: e);
      final cleared = s.copyWith(clearSelectedEntry: true);
      expect(cleared.selectedEntry, isNull);
    });

    test('clearFetchMessage clears both fields', () {
      final s = EpgState(lastFetchMessage: 'ok', lastFetchSuccess: true);
      final cleared = s.copyWith(clearFetchMessage: true);
      expect(cleared.lastFetchMessage, isNull);
      expect(cleared.lastFetchSuccess, isNull);
    });
  });
}
