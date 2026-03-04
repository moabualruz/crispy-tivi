import 'package:crispy_tivi/features/iptv/data/datasources/'
    'channel_local_datasource.dart';
import 'package:crispy_tivi/features/iptv/data/models/'
    'channel_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChannelLocalDatasource datasource;

  // ── Helpers ──────────────────────────────────────

  ChannelModel model({
    String id = 'ch1',
    String name = 'Test Channel',
    String streamUrl = 'http://example.com/s',
    int? number,
    String? group,
    bool isFavorite = false,
    String? sourceId,
  }) {
    return ChannelModel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      number: number,
      group: group,
      isFavorite: isFavorite,
      sourceId: sourceId,
    );
  }

  void seedDefaults() {
    datasource.put(
      model(id: 'ch1', name: 'CNN', group: 'News', sourceId: 'src1'),
    );
    datasource.put(
      model(id: 'ch2', name: 'ESPN', group: 'Sports', sourceId: 'src1'),
    );
    datasource.put(
      model(id: 'ch3', name: 'BBC News', group: 'News', sourceId: 'src2'),
    );
    datasource.put(
      model(
        id: 'ch4',
        name: 'Discovery',
        group: 'Entertainment',
        isFavorite: true,
        sourceId: 'src1',
      ),
    );
  }

  setUp(() {
    datasource = ChannelLocalDatasource();
  });

  // ── getAll ─────────────────────────────────────

  group('getAll', () {
    test('returns empty list when store is empty', () {
      expect(datasource.getAll(), isEmpty);
    });

    test('returns all channels without filter', () {
      seedDefaults();
      final result = datasource.getAll();
      expect(result, hasLength(4));
    });

    test('returns unmodifiable list (no group filter)', () {
      datasource.put(model());
      final result = datasource.getAll();
      expect(
        () => (result as List).add(model(id: 'x')),
        throwsUnsupportedError,
      );
    });

    test('filters by group when group is provided', () {
      seedDefaults();
      final news = datasource.getAll(group: 'News');
      expect(news, hasLength(2));
      expect(news.every((m) => m.group == 'News'), isTrue);
    });

    test('returns empty when group does not match', () {
      seedDefaults();
      final result = datasource.getAll(group: 'Nonexistent');
      expect(result, isEmpty);
    });

    test('ignores empty string group filter', () {
      seedDefaults();
      final result = datasource.getAll(group: '');
      expect(result, hasLength(4));
    });

    test('ignores null group filter', () {
      seedDefaults();
      final result = datasource.getAll(group: null);
      expect(result, hasLength(4));
    });
  });

  // ── search ─────────────────────────────────────

  group('search', () {
    test('returns all channels for empty query', () {
      seedDefaults();
      expect(datasource.search(''), hasLength(4));
    });

    test('matches case-insensitive substring', () {
      seedDefaults();
      final result = datasource.search('cnn');
      expect(result, hasLength(1));
      expect(result.first.id, 'ch1');
    });

    test('matches partial name', () {
      seedDefaults();
      // Only 'BBC News' contains 'News' in name
      final result = datasource.search('News');
      expect(result, hasLength(1));
      expect(result.first.id, 'ch3');
    });

    test('returns empty when no match', () {
      seedDefaults();
      expect(datasource.search('xyz'), isEmpty);
    });

    test('search is case-insensitive both ways', () {
      datasource.put(model(id: 'up', name: 'UPPERCASE'));
      expect(datasource.search('uppercase'), hasLength(1));
      expect(datasource.search('UPPERCASE'), hasLength(1));
    });
  });

  // ── getFavorites ───────────────────────────────

  group('getFavorites', () {
    test('returns empty when no favorites', () {
      seedDefaults();
      // Only ch4 is favorite by default seed
      final favs = datasource.getFavorites();
      expect(favs, hasLength(1));
      expect(favs.first.id, 'ch4');
    });

    test('returns empty when store is empty', () {
      expect(datasource.getFavorites(), isEmpty);
    });

    test('returns multiple favorites', () {
      datasource.put(model(id: 'a', name: 'A', isFavorite: true));
      datasource.put(model(id: 'b', name: 'B', isFavorite: true));
      datasource.put(model(id: 'c', name: 'C', isFavorite: false));
      expect(datasource.getFavorites(), hasLength(2));
    });
  });

  // ── findById ───────────────────────────────────

  group('findById', () {
    test('returns model when found', () {
      seedDefaults();
      final found = datasource.findById('ch2');
      expect(found, isNotNull);
      expect(found!.name, 'ESPN');
    });

    test('returns null when not found', () {
      expect(datasource.findById('missing'), isNull);
    });

    test('returns null on empty store', () {
      expect(datasource.findById('ch1'), isNull);
    });
  });

  // ── put ────────────────────────────────────────

  group('put', () {
    test('inserts new channel', () {
      datasource.put(model(id: 'new1', name: 'New'));
      expect(datasource.count, 1);
      expect(datasource.findById('new1')?.name, 'New');
    });

    test('updates existing channel by id', () {
      datasource.put(model(id: 'ch1', name: 'Original'));
      datasource.put(model(id: 'ch1', name: 'Updated'));
      expect(datasource.count, 1);
      expect(datasource.findById('ch1')?.name, 'Updated');
    });

    test('preserves favorite status on update', () {
      datasource.put(model(id: 'ch1', name: 'Original', isFavorite: true));
      datasource.put(model(id: 'ch1', name: 'Updated', isFavorite: false));
      expect(datasource.findById('ch1')!.isFavorite, isTrue);
    });

    test('does not preserve favorite for new channel', () {
      datasource.put(model(id: 'new', isFavorite: false));
      expect(datasource.findById('new')!.isFavorite, isFalse);
    });
  });

  // ── putAll ─────────────────────────────────────

  group('putAll', () {
    test('inserts multiple channels', () {
      datasource.putAll([
        model(id: 'a', name: 'A'),
        model(id: 'b', name: 'B'),
        model(id: 'c', name: 'C'),
      ]);
      expect(datasource.count, 3);
    });

    test('handles empty list gracefully', () {
      datasource.putAll([]);
      expect(datasource.count, 0);
    });

    test('preserves favorites on batch update', () {
      datasource.put(model(id: 'ch1', name: 'Old', isFavorite: true));
      datasource.putAll([model(id: 'ch1', name: 'New', isFavorite: false)]);
      expect(datasource.findById('ch1')!.isFavorite, isTrue);
    });
  });

  // ── toggleFavorite ─────────────────────────────

  group('toggleFavorite', () {
    test('toggles false to true', () {
      datasource.put(model(id: 'ch1', isFavorite: false));
      final result = datasource.toggleFavorite('ch1');
      expect(result, isNotNull);
      expect(result!.isFavorite, isTrue);
    });

    test('toggles true to false', () {
      datasource.put(model(id: 'ch1', isFavorite: true));
      final result = datasource.toggleFavorite('ch1');
      expect(result, isNotNull);
      expect(result!.isFavorite, isFalse);
    });

    test('returns null for missing channel', () {
      expect(datasource.toggleFavorite('missing'), isNull);
    });

    test('persists toggle in store', () {
      datasource.put(model(id: 'ch1', isFavorite: false));
      datasource.toggleFavorite('ch1');
      expect(datasource.findById('ch1')!.isFavorite, isTrue);
    });
  });

  // ── removeBySource ─────────────────────────────

  group('removeBySource', () {
    test('removes all channels with matching sourceId', () {
      seedDefaults();
      datasource.removeBySource('src1');
      expect(datasource.count, 1);
      expect(datasource.findById('ch3'), isNotNull);
    });

    test('does nothing when sourceId not found', () {
      seedDefaults();
      datasource.removeBySource('nonexistent');
      expect(datasource.count, 4);
    });

    test('handles empty store gracefully', () {
      datasource.removeBySource('any');
      expect(datasource.count, 0);
    });
  });

  // ── removeStaleBySource ────────────────────────

  group('removeStaleBySource', () {
    test('removes channels not in keepIds', () {
      seedDefaults();
      final removed = datasource.removeStaleBySource('src1', {'ch1'});
      // ch2 and ch4 are src1 but not in keepIds
      expect(removed, 2);
      expect(datasource.findById('ch1'), isNotNull);
      expect(datasource.findById('ch2'), isNull);
      expect(datasource.findById('ch4'), isNull);
      // ch3 is src2 — untouched
      expect(datasource.findById('ch3'), isNotNull);
    });

    test('returns 0 when all channels are fresh', () {
      seedDefaults();
      final removed = datasource.removeStaleBySource('src1', {
        'ch1',
        'ch2',
        'ch4',
      });
      expect(removed, 0);
      expect(datasource.count, 4);
    });

    test('returns 0 when source has no channels', () {
      seedDefaults();
      final removed = datasource.removeStaleBySource('nonexistent', <String>{});
      expect(removed, 0);
    });

    test('removes all source channels when keepIds '
        'is empty', () {
      seedDefaults();
      final removed = datasource.removeStaleBySource('src1', <String>{});
      expect(removed, 3);
      expect(datasource.count, 1);
    });
  });

  // ── getAllGroups ────────────────────────────────

  group('getAllGroups', () {
    test('returns empty for empty store', () {
      expect(datasource.getAllGroups(), isEmpty);
    });

    test('returns sorted unique group names', () {
      seedDefaults();
      final groups = datasource.getAllGroups();
      expect(groups, ['Entertainment', 'News', 'Sports']);
    });

    test('excludes null and empty groups', () {
      datasource.put(model(id: 'a', name: 'A', group: null));
      datasource.put(model(id: 'b', name: 'B', group: ''));
      datasource.put(model(id: 'c', name: 'C', group: 'Valid'));
      expect(datasource.getAllGroups(), ['Valid']);
    });

    test('deduplicates group names', () {
      datasource.put(model(id: 'a', name: 'A', group: 'News'));
      datasource.put(model(id: 'b', name: 'B', group: 'News'));
      expect(datasource.getAllGroups(), ['News']);
    });
  });

  // ── count ──────────────────────────────────────

  group('count', () {
    test('returns 0 for empty store', () {
      expect(datasource.count, 0);
    });

    test('returns correct count after inserts', () {
      seedDefaults();
      expect(datasource.count, 4);
    });

    test('decrements after removal', () {
      seedDefaults();
      datasource.removeBySource('src1');
      expect(datasource.count, 1);
    });
  });
}
