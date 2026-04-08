import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_list_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a minimal [Channel] for testing.
Channel ch(
  String id,
  String name, {
  int? number,
  String? group,
  bool isFavorite = false,
  String? sourceId,
  DateTime? addedAt,
}) {
  return Channel(
    id: id,
    name: name,
    streamUrl: 'http://stream/$id',
    number: number,
    group: group,
    isFavorite: isFavorite,
    sourceId: sourceId,
    addedAt: addedAt,
  );
}

/// Shorthand — call [filterAndSortChannels] with defaults for
/// parameters not under test.
List<Channel> filter(
  List<Channel> channels, {
  String searchQuery = '',
  ChannelSortMode sortMode = ChannelSortMode.defaultOrder,
  ChannelGroupMode groupMode = ChannelGroupMode.byCategory,
  String? selectedGroup,
  Set<String> hiddenGroups = const {},
  Set<String> hiddenChannelIds = const {},
  bool hideDuplicates = false,
  Set<String> duplicateIds = const {},
  Map<String, int>? customOrderMap,
  Map<String, String> sourceNames = const {},
  Map<String, DateTime> lastWatchedMap = const {},
}) {
  return filterAndSortChannels(
    channels,
    searchQuery: searchQuery,
    sortMode: sortMode,
    groupMode: groupMode,
    selectedGroup: selectedGroup,
    hiddenGroups: hiddenGroups,
    hiddenChannelIds: hiddenChannelIds,
    hideDuplicates: hideDuplicates,
    duplicateIds: duplicateIds,
    customOrderMap: customOrderMap,
    sourceNames: sourceNames,
    lastWatchedMap: lastWatchedMap,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Sample channels ──────────────────────────────────────────────────────

  final base = DateTime(2024, 1, 1);

  final chA = ch('a', 'Alpha', number: 3, group: 'Sports');
  final chB = ch('b', 'Bravo', number: 1, group: 'News');
  final chC = ch('c', 'Charlie', number: 2, group: 'Sports');
  final chD = ch('d', 'Delta', group: 'Movies'); // no number
  final chE = ch('e', 'Echo', number: 4, group: 'News', isFavorite: true);
  final chF = ch('f', 'Foxtrot', number: 5, group: 'Sports', isFavorite: true);

  final channels = [chA, chB, chC, chD, chE, chF];

  // ── Edge cases ────────────────────────────────────────────────────────────

  group('edge cases', () {
    test('empty list returns empty list', () {
      expect(filter([]), isEmpty);
    });

    test('no matches on search returns empty list', () {
      final result = filter(channels, searchQuery: 'zzz');
      expect(result, isEmpty);
    });

    test('all hidden by id returns empty list', () {
      final ids = channels.map((c) => c.id).toSet();
      expect(filter(channels, hiddenChannelIds: ids), isEmpty);
    });

    test('all hidden by group returns empty list', () {
      expect(
        filter(channels, hiddenGroups: {'Sports', 'News', 'Movies'}),
        isEmpty,
      );
    });

    test('single channel passes through unmodified', () {
      final result = filter([chA]);
      expect(result, [chA]);
    });
  });

  // ── Sort modes ────────────────────────────────────────────────────────────

  group('sort: defaultOrder', () {
    test('sorts by number ascending, nulls last', () {
      final result = filter([chD, chA, chC, chB]);
      // chB(1), chC(2), chA(3), chD(no number) — nulls last alphabetically
      expect(result.map((c) => c.id), ['b', 'c', 'a', 'd']);
    });

    test('null-number channels sort alphabetically among themselves', () {
      final n1 = ch('x', 'Zulu');
      final n2 = ch('y', 'Alpha');
      final result = filter([n1, n2]);
      expect(result, [n2, n1]);
    });

    test('numbered channels come before unnumbered', () {
      final result = filter([chD, chA]);
      expect(result.first.id, 'a'); // chA has number 3
    });
  });

  group('sort: byName', () {
    test('sorts alphabetically by name case-insensitive', () {
      final result = filter(channels, sortMode: ChannelSortMode.byName);
      final names = result.map((c) => c.name.toLowerCase()).toList();
      expect(names, [...names]..sort());
    });

    test('upper and lower case treated equally', () {
      final lower = ch('lo', 'alpha', number: 2);
      final upper = ch('up', 'Alpha', number: 1);
      final result = filter([lower, upper], sortMode: ChannelSortMode.byName);
      // Both start with 'alpha' — stable relative order
      expect(result.map((c) => c.name.toLowerCase()), everyElement('alpha'));
    });
  });

  group('sort: byDateAdded', () {
    test('most recently added first', () {
      final old = ch('old', 'Old', addedAt: base);
      final mid = ch('mid', 'Mid', addedAt: base.add(const Duration(days: 1)));
      final newC = ch('new', 'New', addedAt: base.add(const Duration(days: 2)));
      final result = filter([
        old,
        newC,
        mid,
      ], sortMode: ChannelSortMode.byDateAdded);
      expect(result.map((c) => c.id), ['new', 'mid', 'old']);
    });

    test('channels with no date sort by default after dated ones', () {
      final dated = ch('d', 'Dated', addedAt: base);
      final noDate = ch('n', 'NoDate');
      final result = filter([
        noDate,
        dated,
      ], sortMode: ChannelSortMode.byDateAdded);
      expect(result.first.id, 'd');
    });

    test('two undated channels fall back to default sort', () {
      final n1 = ch('z', 'Zulu', number: 1);
      final n2 = ch('a', 'Alpha', number: 2);
      final result = filter([n2, n1], sortMode: ChannelSortMode.byDateAdded);
      // default sort: by number — n1(1) before n2(2)
      expect(result.map((c) => c.id), ['z', 'a']);
    });
  });

  group('sort: byWatchTime', () {
    test('most recently watched first', () {
      final t0 = base;
      final t1 = base.add(const Duration(hours: 1));
      final t2 = base.add(const Duration(hours: 2));
      final watched = {'a': t0, 'b': t2, 'c': t1};
      final result = filter(
        [chA, chB, chC],
        sortMode: ChannelSortMode.byWatchTime,
        lastWatchedMap: watched,
      );
      expect(result.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('unwatched channels come after watched', () {
      final watched = {'a': base};
      final result = filter(
        [chC, chA], // chC has no watch time
        sortMode: ChannelSortMode.byWatchTime,
        lastWatchedMap: watched,
      );
      expect(result.first.id, 'a');
    });

    test('two unwatched channels fall back to default sort', () {
      // chB(1) vs chA(3) — default sort by number
      final result = filter([chA, chB], sortMode: ChannelSortMode.byWatchTime);
      expect(result.map((c) => c.id), ['b', 'a']);
    });
  });

  group('sort: manual', () {
    test('sorts by custom order map', () {
      final order = {'a': 3, 'b': 1, 'c': 2};
      final result = filter(
        [chA, chB, chC],
        sortMode: ChannelSortMode.manual,
        customOrderMap: order,
      );
      expect(result.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('channels not in map sort after mapped ones by default', () {
      final order = {'a': 1};
      final result = filter(
        [chC, chA, chB],
        sortMode: ChannelSortMode.manual,
        customOrderMap: order,
      );
      // chA first (in map), then chB(1) and chC(2) by default number sort
      expect(result.first.id, 'a');
      expect(
        result.map((c) => c.id).toList().sublist(1),
        containsAll(['b', 'c']),
      );
    });

    test('null/empty custom order falls back to default sort', () {
      final result = filter([chA, chC, chB], sortMode: ChannelSortMode.manual);
      // default: by number — b(1), c(2), a(3)
      expect(result.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('empty custom order map falls back to default sort', () {
      final result = filter(
        [chA, chC, chB],
        sortMode: ChannelSortMode.manual,
        customOrderMap: {},
      );
      expect(result.map((c) => c.id), ['b', 'c', 'a']);
    });
  });

  // ── Group modes ───────────────────────────────────────────────────────────

  group('group: byCategory', () {
    test('filters to selected group', () {
      final result = filter(
        channels,
        selectedGroup: 'Sports',
        groupMode: ChannelGroupMode.byCategory,
      );
      expect(result.every((c) => c.group == 'Sports'), isTrue);
    });

    test('no group selected returns all channels', () {
      // No favorites in this subset → no effectiveGroup override
      final noFav = [chA, chB, chC, chD];
      final result = filter(noFav, groupMode: ChannelGroupMode.byCategory);
      expect(result.length, noFav.length);
    });

    test('favorites group returns only favorited channels', () {
      final result = filter(
        channels,
        selectedGroup: ChannelListState.favoritesGroup,
        groupMode: ChannelGroupMode.byCategory,
      );
      expect(result.every((c) => c.isFavorite), isTrue);
      expect(result.map((c) => c.id), containsAll(['e', 'f']));
    });
  });

  group('group: byPlaylist', () {
    final src1 = ch('p1', 'Sport 1', sourceId: 'src-a', group: 'Sports');
    final src2 = ch('p2', 'Sport 2', sourceId: 'src-a', group: 'Sports');
    final src3 = ch('p3', 'News 1', sourceId: 'src-b', group: 'News');
    final sourceNames = {'src-a': 'Source Alpha', 'src-b': 'Source Beta'};

    test('filters by resolved source id from display name', () {
      final result = filter(
        [src1, src2, src3],
        selectedGroup: 'Source Alpha',
        groupMode: ChannelGroupMode.byPlaylist,
        sourceNames: sourceNames,
      );
      expect(result.map((c) => c.id), containsAll(['p1', 'p2']));
      expect(result.length, 2);
    });

    test('unknown display name treated as source id literal', () {
      final direct = ch('dx', 'Direct', sourceId: 'raw-id');
      final result = filter(
        [direct, src1],
        selectedGroup: 'raw-id',
        groupMode: ChannelGroupMode.byPlaylist,
        sourceNames: sourceNames,
      );
      expect(result, [direct]);
    });

    test('favorites group still works with byPlaylist mode', () {
      final fav = ch('fv', 'Fav', sourceId: 'src-a', isFavorite: true);
      final nonFav = ch('nf', 'NonFav', sourceId: 'src-a');
      final result = filter(
        [fav, nonFav],
        selectedGroup: ChannelListState.favoritesGroup,
        groupMode: ChannelGroupMode.byPlaylist,
        sourceNames: sourceNames,
      );
      expect(result, [fav]);
    });
  });

  // ── Search filtering ──────────────────────────────────────────────────────

  group('search', () {
    test('matches channel name case-insensitively', () {
      final result = filter(channels, searchQuery: 'alpha');
      expect(result.map((c) => c.id), ['a']);
    });

    test('matches group name case-insensitively', () {
      final result = filter(channels, searchQuery: 'sport');
      expect(result.every((c) => c.group == 'Sports'), isTrue);
    });

    test('matches partial name', () {
      final result = filter(channels, searchQuery: 'av');
      // "Bravo" contains 'av'
      expect(result.any((c) => c.id == 'b'), isTrue);
    });

    test('empty search returns all (after other filters)', () {
      final result = filter(channels, searchQuery: '');
      expect(result.length, channels.length);
    });

    test('search combines with group filter', () {
      final result = filter(
        channels,
        selectedGroup: 'Sports',
        searchQuery: 'alpha',
      );
      expect(result, [chA]);
    });
  });

  // ── Exclusion passes ──────────────────────────────────────────────────────

  group('hidden groups', () {
    test('excludes channels in hidden group', () {
      final result = filter(channels, hiddenGroups: {'Sports'});
      expect(result.any((c) => c.group == 'Sports'), isFalse);
    });

    test('multiple hidden groups all excluded', () {
      final result = filter(channels, hiddenGroups: {'Sports', 'News'});
      expect(result, [chD]); // only Movies channel remains
    });

    test('empty hidden groups set excludes nothing', () {
      final result = filter(channels, hiddenGroups: {});
      expect(result.length, channels.length);
    });
  });

  group('hidden channel ids', () {
    test('excludes specific channel by id', () {
      final result = filter(channels, hiddenChannelIds: {'a', 'c'});
      expect(result.any((c) => c.id == 'a'), isFalse);
      expect(result.any((c) => c.id == 'c'), isFalse);
    });

    test('channel not in hidden ids is kept', () {
      final result = filter(channels, hiddenChannelIds: {'a'});
      expect(result.any((c) => c.id == 'b'), isTrue);
    });
  });

  group('duplicate exclusion', () {
    test('excludes duplicate ids when hideDuplicates is true', () {
      final result = filter(
        channels,
        hideDuplicates: true,
        duplicateIds: {'a', 'b'},
      );
      expect(result.any((c) => c.id == 'a'), isFalse);
      expect(result.any((c) => c.id == 'b'), isFalse);
    });

    test('duplicates kept when hideDuplicates is false', () {
      final result = filter(
        channels,
        hideDuplicates: false,
        duplicateIds: {'a', 'b'},
      );
      expect(result.any((c) => c.id == 'a'), isTrue);
    });

    test('no-op when duplicateIds is empty', () {
      final result = filter(channels, hideDuplicates: true, duplicateIds: {});
      expect(result.length, channels.length);
    });
  });

  // ── Combined scenarios ────────────────────────────────────────────────────

  group('combined filter + sort', () {
    test('hidden group + search + byName sort', () {
      // Hide Movies, search for 'a', sort by name
      final result = filter(
        channels,
        hiddenGroups: {'Movies'},
        searchQuery: 'a',
        sortMode: ChannelSortMode.byName,
      );
      // "Alpha"(Sports), "Bravo"(News), "Charlie"(Sports) contain 'a'
      // Movies excluded → chD (Delta) gone, but Delta doesn't contain 'a'
      expect(result.every((c) => c.group != 'Movies'), isTrue);
      final names = result.map((c) => c.name.toLowerCase()).toList();
      expect(names, [...names]..sort());
    });

    test('favorite group with byWatchTime sort', () {
      final watched = {'e': base, 'f': base.add(const Duration(hours: 1))};
      final result = filter(
        channels,
        selectedGroup: ChannelListState.favoritesGroup,
        sortMode: ChannelSortMode.byWatchTime,
        lastWatchedMap: watched,
      );
      expect(result.every((c) => c.isFavorite), isTrue);
      // chF watched most recently
      expect(result.first.id, 'f');
    });

    test('hidden id + group filter + defaultOrder sort', () {
      final result = filter(
        channels,
        selectedGroup: 'Sports',
        hiddenChannelIds: {'a'}, // hide Alpha
      );
      // Only chC(2) and chF(5) in Sports remain
      expect(result.map((c) => c.id), containsAll(['c', 'f']));
      expect(result.any((c) => c.id == 'a'), isFalse);
    });
  });
}
