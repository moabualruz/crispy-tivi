import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/epg_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryBackend backend;
  late CacheService cache;

  setUp(() {
    backend = MemoryBackend();
    cache = CacheService(backend);
  });

  // ── Helpers ─────────────────────────────────────

  DateTime utc(int y, int m, int d, [int h = 0, int min = 0]) =>
      DateTime.utc(y, m, d, h, min);

  EpgEntry makeEntry({
    String channelId = 'ch1',
    String title = 'Show',
    DateTime? start,
    DateTime? end,
    String? description,
    String? category,
    String? iconUrl,
  }) => EpgEntry(
    channelId: channelId,
    title: title,
    startTime: start ?? utc(2026, 2, 22, 10),
    endTime: end ?? utc(2026, 2, 22, 11),
    description: description,
    category: category,
    iconUrl: iconUrl,
  );

  // ── Save + Load round-trip ──────────────────────

  group('EPG save/load round-trip', () {
    test('save and load preserves entries', () async {
      final entries = <String, List<EpgEntry>>{
        'ch1': [
          makeEntry(title: 'News'),
          makeEntry(
            title: 'Movie',
            start: utc(2026, 2, 22, 11),
            end: utc(2026, 2, 22, 13),
          ),
        ],
        'ch2': [makeEntry(channelId: 'ch2', title: 'Sports')],
      };

      await cache.saveEpgEntries(entries);
      final loaded = await cache.loadEpgEntries();

      expect(loaded.keys.length, 2);
      expect(loaded['ch1']!.length, 2);
      expect(loaded['ch2']!.length, 1);
      expect(loaded['ch1']![0].title, 'News');
      expect(loaded['ch1']![1].title, 'Movie');
      expect(loaded['ch2']![0].title, 'Sports');
    });

    test('preserves all optional fields', () async {
      final entries = <String, List<EpgEntry>>{
        'ch1': [
          makeEntry(
            title: 'Full Entry',
            description: 'A great show',
            category: 'Drama',
            iconUrl: 'http://img.png',
          ),
        ],
      };

      await cache.saveEpgEntries(entries);
      final loaded = await cache.loadEpgEntries();

      final e = loaded['ch1']!.first;
      expect(e.description, 'A great show');
      expect(e.category, 'Drama');
      expect(e.iconUrl, 'http://img.png');
    });

    test('preserves DateTime precision', () async {
      final start = utc(2026, 2, 22, 10, 15);
      final end = utc(2026, 2, 22, 11, 45);
      final entries = <String, List<EpgEntry>>{
        'ch1': [makeEntry(start: start, end: end)],
      };

      await cache.saveEpgEntries(entries);
      final loaded = await cache.loadEpgEntries();

      final e = loaded['ch1']!.first;
      expect(e.startTime, start);
      expect(e.endTime, end);
    });

    test('handles null optional fields', () async {
      final entries = <String, List<EpgEntry>>{
        'ch1': [makeEntry()],
      };

      await cache.saveEpgEntries(entries);
      final loaded = await cache.loadEpgEntries();

      final e = loaded['ch1']!.first;
      expect(e.description, isNull);
      expect(e.category, isNull);
      expect(e.iconUrl, isNull);
    });
  });

  // ── clearEpgEntries ─────────────────────────────

  group('clearEpgEntries', () {
    test('clears all entries', () async {
      await cache.saveEpgEntries({
        'ch1': [makeEntry()],
      });
      await cache.clearEpgEntries();
      final loaded = await cache.loadEpgEntries();
      expect(loaded, isEmpty);
    });
  });

  // ── evictStaleEpgEntries ────────────────────────

  group('evictStaleEpgEntries', () {
    test('removes entries older than N days', () async {
      final fresh = makeEntry(
        title: 'Fresh',
        start: DateTime.now().toUtc(),
        end: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      final stale = makeEntry(
        title: 'Stale',
        start: DateTime.now().toUtc().subtract(const Duration(days: 10)),
        end: DateTime.now().toUtc().subtract(const Duration(days: 9)),
      );
      await cache.saveEpgEntries({
        'ch1': [fresh, stale],
      });

      final removed = await cache.evictStaleEpgEntries(days: 2);

      expect(removed, 1);
      final loaded = await cache.loadEpgEntries();
      expect(loaded['ch1']!.length, 1);
      expect(loaded['ch1']!.first.title, 'Fresh');
    });

    test('returns 0 when nothing stale', () async {
      final fresh = makeEntry(
        start: DateTime.now().toUtc(),
        end: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      await cache.saveEpgEntries({
        'ch1': [fresh],
      });

      final removed = await cache.evictStaleEpgEntries(days: 2);
      expect(removed, 0);
    });
  });

  // ── Upsert behavior ────────────────────────────

  group('upsert behavior', () {
    test('second save overwrites channel entries', () async {
      await cache.saveEpgEntries({
        'ch1': [makeEntry(title: 'Old')],
      });
      await cache.saveEpgEntries({
        'ch1': [makeEntry(title: 'New')],
      });

      final loaded = await cache.loadEpgEntries();
      expect(loaded['ch1']!.length, 1);
      expect(loaded['ch1']!.first.title, 'New');
    });

    test('save preserves other channels', () async {
      await cache.saveEpgEntries({
        'ch1': [makeEntry(title: 'A')],
      });
      await cache.saveEpgEntries({
        'ch2': [makeEntry(channelId: 'ch2', title: 'B')],
      });

      final loaded = await cache.loadEpgEntries();
      expect(loaded.keys.length, 2);
    });
  });

  // ── mapToEpgEntry / epgEntryToMap ───────────────

  group('serialization helpers', () {
    test('epgEntryToMap produces expected keys', () {
      final e = makeEntry(
        channelId: 'x',
        title: 'T',
        description: 'D',
        category: 'C',
        iconUrl: 'U',
      );
      final map = epgEntryToMap(e);
      expect(map['channel_id'], 'x');
      expect(map['title'], 'T');
      expect(map['description'], 'D');
      expect(map['category'], 'C');
      expect(map['icon_url'], 'U');
      expect(map['start_time'], isNotNull);
      expect(map['end_time'], isNotNull);
    });

    test('mapToEpgEntry round-trips via map', () {
      final original = makeEntry(
        channelId: 'ch1',
        title: 'Test',
        description: 'desc',
        category: 'cat',
        iconUrl: 'http://icon',
      );
      final map = epgEntryToMap(original);
      final restored = mapToEpgEntry(map);

      expect(restored.channelId, original.channelId);
      expect(restored.title, original.title);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.description, original.description);
      expect(restored.category, original.category);
      expect(restored.iconUrl, original.iconUrl);
    });
  });
}
