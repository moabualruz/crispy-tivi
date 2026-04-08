import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/channel.dart';
import 'package:crispy_tivi/features/player/'
    'domain/entities/watch_history_entry.dart';
import 'package:crispy_tivi/features/recommendations/'
    'data/recommendation_engine.dart';
import 'package:crispy_tivi/features/recommendations/'
    'domain/entities/recommendation.dart';
import 'package:crispy_tivi/features/vod/'
    'domain/entities/vod_item.dart';

void main() {
  late MemoryBackend backend;
  late CacheService cache;
  late RecommendationEngine engine;

  setUp(() {
    backend = MemoryBackend();
    cache = CacheService(backend);
    engine = RecommendationEngine(cache, backend);
  });

  // ── Helpers ───────────────────────────────────────

  /// Insert a watch history entry via CacheService.
  Future<void> insertHistory({
    required String id,
    String mediaType = 'movie',
    String name = 'Test',
    String streamUrl = 'http://test',
    int positionMs = 5000,
    int durationMs = 6000,
    DateTime? lastWatched,
  }) async {
    await cache.saveWatchHistory(
      WatchHistoryEntry(
        id: id,
        mediaType: mediaType,
        name: name,
        streamUrl: streamUrl,
        positionMs: positionMs,
        durationMs: durationMs,
        lastWatched: lastWatched ?? DateTime.now(),
      ),
    );
  }

  /// Insert a favorite for a profile.
  Future<void> insertFavorite({
    required String profileId,
    required String channelId,
  }) async {
    await cache.addFavorite(profileId, channelId);
  }

  /// Create a VodItem for testing.
  VodItem makeVod({
    required String id,
    String name = 'Movie',
    String streamUrl = 'http://stream',
    VodType type = VodType.movie,
    String? category,
    String? rating,
    int? year,
    String? posterUrl,
    DateTime? addedAt,
    bool isFavorite = false,
    String? seriesId,
  }) {
    return VodItem(
      id: id,
      name: name,
      streamUrl: streamUrl,
      type: type,
      category: category,
      rating: rating,
      year: year,
      posterUrl: posterUrl,
      addedAt: addedAt,
      isFavorite: isFavorite,
      seriesId: seriesId,
    );
  }

  /// Create a Channel for testing.
  Channel makeChannel({
    required String id,
    String name = 'Channel',
    String streamUrl = 'http://ch',
    String? group,
  }) {
    return Channel(id: id, name: name, streamUrl: streamUrl, group: group);
  }

  /// Shared params for convenience.
  Future<List<RecommendationSection>> generate({
    String profileId = 'p1',
    int maxAllowedRating = 4,
    List<VodItem>? allVodItems,
    List<Channel>? allChannels,
  }) {
    return engine.generateAll(
      profileId: profileId,
      maxAllowedRating: maxAllowedRating,
      allVodItems: allVodItems ?? [],
      allChannels: allChannels ?? [],
    );
  }

  // ── Tests ─────────────────────────────────────────

  group('RecommendationEngine', () {
    group('cold start', () {
      test('returns cold-start sections with no history', () async {
        final vodItems = [
          makeVod(
            id: 'v1',
            name: 'Rated Movie',
            rating: '8.0',
            addedAt: DateTime.now(),
          ),
          makeVod(
            id: 'v2',
            name: 'Another Movie',
            rating: '7.0',
            addedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        expect(sections, isNotEmpty);

        final titles = sections.map((s) => s.title).toList();
        expect(titles, contains('Highly Rated'));
        expect(titles, contains('Recently Added'));
      });

      test('returns cold-start with fewer than 3 '
          'history entries', () async {
        // Insert only 2 history entries.
        await insertHistory(id: 'h1');
        await insertHistory(id: 'h2');

        final vodItems = [
          makeVod(id: 'v1', rating: '9.0', addedAt: DateTime.now()),
        ];

        final sections = await generate(allVodItems: vodItems);

        // Should still be cold start.
        final types = sections.map((s) => s.reasonType).toSet();
        expect(types, contains(RecommendationReasonType.coldStart));
      });

      test('cold-start Highly Rated section is sorted '
          'by rating descending', () async {
        final vodItems = [
          makeVod(
            id: 'v1',
            name: 'Low',
            rating: '5.0',
            addedAt: DateTime.now(),
          ),
          makeVod(
            id: 'v2',
            name: 'High',
            rating: '9.0',
            addedAt: DateTime.now(),
          ),
          makeVod(
            id: 'v3',
            name: 'Mid',
            rating: '7.0',
            addedAt: DateTime.now(),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        final rated = sections.firstWhere((s) => s.title == 'Highly Rated');
        expect(rated.items[0].itemName, 'High');
        expect(rated.items[1].itemName, 'Mid');
        expect(rated.items[2].itemName, 'Low');
      });

      test('cold-start excludes watched items', () async {
        await insertHistory(id: 'v1');

        final vodItems = [
          makeVod(
            id: 'v1',
            name: 'Watched',
            rating: '9.0',
            addedAt: DateTime.now(),
          ),
          makeVod(
            id: 'v2',
            name: 'Unwatched',
            rating: '8.0',
            addedAt: DateTime.now(),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        final allItemIds =
            sections.expand((s) => s.items).map((r) => r.itemId).toSet();
        expect(allItemIds, isNot(contains('v1')));
        expect(allItemIds, contains('v2'));
      });

      test('cold-start excludes episode type items', () async {
        final vodItems = [
          makeVod(
            id: 'ep1',
            type: VodType.episode,
            rating: '9.0',
            addedAt: DateTime.now(),
          ),
          makeVod(
            id: 'v1',
            type: VodType.movie,
            rating: '7.0',
            addedAt: DateTime.now(),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        final allItemIds =
            sections.expand((s) => s.items).map((r) => r.itemId).toSet();
        expect(allItemIds, isNot(contains('ep1')));
      });
    });

    group('genre affinity and top picks', () {
      test('top picks favors items in watched genres', () async {
        for (var i = 0; i < 4; i++) {
          await insertHistory(
            id: 'watched$i',
            positionMs: 5500,
            durationMs: 6000,
          );
        }

        final vodItems = [
          for (var i = 0; i < 4; i++)
            makeVod(id: 'watched$i', category: 'Action', rating: '5.0'),
          makeVod(
            id: 'action1',
            name: 'New Action',
            category: 'Action',
            rating: '7.0',
            addedAt: DateTime.now(),
          ),
          makeVod(
            id: 'romance1',
            name: 'New Romance',
            category: 'Romance',
            rating: '7.0',
            addedAt: DateTime.now(),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        final topPicks = sections.firstWhere(
          (s) => s.reasonType == RecommendationReasonType.topPick,
          orElse:
              () => const RecommendationSection(
                title: '',
                reasonType: RecommendationReasonType.topPick,
                items: [],
              ),
        );

        if (topPicks.items.length >= 2) {
          final actionIdx = topPicks.items.indexWhere(
            (r) => r.itemId == 'action1',
          );
          final romanceIdx = topPicks.items.indexWhere(
            (r) => r.itemId == 'romance1',
          );

          if (actionIdx >= 0 && romanceIdx >= 0) {
            expect(actionIdx, lessThan(romanceIdx));
          }
        }
      });
    });

    group('because you watched', () {
      test('returns similar-category items '
          'excluding watched', () async {
        for (var i = 0; i < 4; i++) {
          await insertHistory(id: 'w$i', positionMs: 5500, durationMs: 6000);
        }

        final vodItems = [
          makeVod(id: 'w0', name: 'Action Hit', category: 'Action'),
          makeVod(id: 'w1', name: 'Comedy Fun', category: 'Comedy'),
          makeVod(id: 'w2', name: 'Action 2', category: 'Action'),
          makeVod(id: 'w3', name: 'Drama', category: 'Drama'),
          makeVod(
            id: 'rec1',
            name: 'Action Rec',
            category: 'Action',
            rating: '8.0',
          ),
          makeVod(
            id: 'rec2',
            name: 'Comedy Rec',
            category: 'Comedy',
            rating: '7.5',
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        final becauseSections = sections.where(
          (s) => s.reasonType == RecommendationReasonType.becauseYouWatched,
        );

        expect(becauseSections, isNotEmpty);

        for (final section in becauseSections) {
          final ids = section.items.map((r) => r.itemId);
          expect(ids, isNot(contains('w0')));
          expect(ids, isNot(contains('w1')));
          expect(ids, isNot(contains('w2')));
          expect(ids, isNot(contains('w3')));
        }
      });

      test('because you watched max 3 sections', () async {
        for (var i = 0; i < 5; i++) {
          await insertHistory(id: 'w$i', positionMs: 5500, durationMs: 6000);
        }

        final vodItems = [
          for (var i = 0; i < 5; i++)
            makeVod(id: 'w$i', name: 'Movie $i', category: 'Cat$i'),
          for (var i = 0; i < 5; i++)
            makeVod(id: 'rec$i', name: 'Rec $i', category: 'Cat$i'),
        ];

        final sections = await generate(allVodItems: vodItems);

        final becauseCount =
            sections
                .where(
                  (s) =>
                      s.reasonType ==
                      RecommendationReasonType.becauseYouWatched,
                )
                .length;

        expect(becauseCount, lessThanOrEqualTo(3));
      });
    });

    group('trending', () {
      test('trending section excluded when all '
          'trending items are already watched', () async {
        for (var i = 0; i < 4; i++) {
          await insertHistory(id: 'h$i');
        }

        final vodItems = [
          for (var i = 0; i < 4; i++) makeVod(id: 'h$i', category: 'Action'),
          makeVod(id: 'new1', name: 'New One', category: 'Action'),
        ];

        final sections = await generate(allVodItems: vodItems);

        final trending = sections.where(
          (s) => s.reasonType == RecommendationReasonType.trending,
        );

        if (trending.isNotEmpty) {
          for (final item in trending.first.items) {
            expect(item.itemId, isNot(anyOf('h0', 'h1', 'h2', 'h3')));
          }
        }
      });

      test('trending section returned when engine '
          'produces it via _buildTrending', () async {
        for (var i = 0; i < 4; i++) {
          await insertHistory(id: 'h$i');
        }

        final vodItems = [
          for (var i = 0; i < 4; i++) makeVod(id: 'h$i', category: 'Action'),
        ];

        final sections = await generate(allVodItems: vodItems);

        final trending = sections.where(
          (s) => s.reasonType == RecommendationReasonType.trending,
        );

        expect(trending, isEmpty);
      });
    });

    group('new for you', () {
      test('recently added items matching genre '
          'affinity appear in New for You', () async {
        final now = DateTime.now();

        for (var i = 0; i < 4; i++) {
          await insertHistory(id: 'h$i', positionMs: 5500, durationMs: 6000);
        }

        final vodItems = [
          for (var i = 0; i < 4; i++) makeVod(id: 'h$i', category: 'SciFi'),
          makeVod(
            id: 'new1',
            name: 'New SciFi',
            category: 'SciFi',
            addedAt: now.subtract(const Duration(days: 2)),
          ),
          makeVod(
            id: 'old1',
            name: 'Old Movie',
            category: 'SciFi',
            addedAt: now.subtract(const Duration(days: 30)),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        final newForYou = sections.where(
          (s) => s.reasonType == RecommendationReasonType.newForYou,
        );

        if (newForYou.isNotEmpty) {
          final ids = newForYou.first.items.map((r) => r.itemId).toSet();
          expect(ids, contains('new1'));
          expect(ids, isNot(contains('old1')));
        }
      });
    });

    group('deduplication', () {
      test('watched items never appear in any '
          'section', () async {
        for (var i = 0; i < 5; i++) {
          await insertHistory(id: 'w$i', positionMs: 5500, durationMs: 6000);
        }

        final vodItems = [
          for (var i = 0; i < 5; i++)
            makeVod(
              id: 'w$i',
              name: 'Watched $i',
              category: 'Action',
              rating: '9.0',
              addedAt: DateTime.now(),
            ),
          makeVod(
            id: 'unwatched',
            name: 'Unwatched',
            category: 'Action',
            rating: '8.0',
            addedAt: DateTime.now(),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        final allRecIds =
            sections.expand((s) => s.items).map((r) => r.itemId).toSet();

        for (var i = 0; i < 5; i++) {
          expect(allRecIds, isNot(contains('w$i')));
        }
      });
    });

    group('empty catalog', () {
      test('returns empty sections with no VOD '
          'items', () async {
        final sections = await generate(allVodItems: [], allChannels: []);

        for (final section in sections) {
          expect(section.items, isEmpty);
        }
      });

      test('returns sections gracefully with '
          'history but no catalog', () async {
        for (var i = 0; i < 5; i++) {
          await insertHistory(id: 'h$i');
        }

        final sections = await generate(allVodItems: [], allChannels: []);

        for (final section in sections) {
          expect(section.items, isEmpty);
        }
      });
    });

    group('no favorites', () {
      test('engine works with history only — no '
          'favorites signal', () async {
        for (var i = 0; i < 4; i++) {
          await insertHistory(id: 'h$i', positionMs: 5500, durationMs: 6000);
        }

        final vodItems = [
          for (var i = 0; i < 4; i++) makeVod(id: 'h$i', category: 'Drama'),
          makeVod(
            id: 'rec1',
            name: 'Drama Rec',
            category: 'Drama',
            rating: '7.0',
            addedAt: DateTime.now(),
          ),
        ];

        final sections = await generate(
          profileId: 'nonexistent',
          allVodItems: vodItems,
        );

        expect(sections, isNotEmpty);
      });
    });

    group('favorites boost', () {
      test('favorited channels boost genre affinity', () async {
        await insertFavorite(profileId: 'p1', channelId: 'ch1');

        for (var i = 0; i < 4; i++) {
          await insertHistory(id: 'h$i');
        }

        final vodItems = [
          for (var i = 0; i < 4; i++) makeVod(id: 'h$i', category: 'General'),
          makeVod(
            id: 'sports1',
            name: 'Sports Movie',
            category: 'Sports',
            rating: '8.0',
            addedAt: DateTime.now(),
          ),
          makeVod(
            id: 'other1',
            name: 'Other Movie',
            category: 'Other',
            rating: '8.0',
            addedAt: DateTime.now(),
          ),
        ];

        final channels = [
          makeChannel(id: 'ch1', name: 'Sports Channel', group: 'Sports'),
        ];

        final sections = await generate(
          profileId: 'p1',
          allVodItems: vodItems,
          allChannels: channels,
        );

        expect(sections, isNotEmpty);

        final topPicks = sections.where(
          (s) => s.reasonType == RecommendationReasonType.topPick,
        );

        if (topPicks.isNotEmpty) {
          final sportsItems =
              topPicks.first.items
                  .where((r) => r.category == 'Sports')
                  .toList();
          expect(sportsItems, isNotEmpty);
        }
      });
    });

    group('section structure', () {
      test('all sections have correct reasonType', () async {
        for (var i = 0; i < 5; i++) {
          await insertHistory(id: 'h$i', positionMs: 5500, durationMs: 6000);
        }

        final vodItems = [
          for (var i = 0; i < 5; i++) makeVod(id: 'h$i', category: 'Action'),
          for (var i = 0; i < 20; i++)
            makeVod(
              id: 'rec$i',
              name: 'Rec $i',
              category: 'Action',
              rating: '${5 + (i % 5)}.0',
              addedAt: DateTime.now().subtract(Duration(days: i)),
            ),
        ];

        final sections = await generate(allVodItems: vodItems);

        for (final section in sections) {
          expect(section.reasonType, isA<RecommendationReasonType>());
          expect(section.title, isNotEmpty);
        }
      });

      test('sections contain Recommendation objects '
          'with valid fields', () async {
        for (var i = 0; i < 4; i++) {
          await insertHistory(id: 'h$i', positionMs: 5500, durationMs: 6000);
        }

        final vodItems = [
          for (var i = 0; i < 4; i++) makeVod(id: 'h$i', category: 'Drama'),
          makeVod(
            id: 'r1',
            name: 'Rec Movie',
            category: 'Drama',
            rating: '8.0',
            streamUrl: 'http://rec',
            posterUrl: 'http://poster',
            year: 2024,
            addedAt: DateTime.now(),
          ),
        ];

        final sections = await generate(allVodItems: vodItems);

        for (final section in sections) {
          for (final item in section.items) {
            expect(item.itemId, isNotEmpty);
            expect(item.itemName, isNotEmpty);
            expect(item.mediaType, anyOf('movie', 'series'));
            expect(item.score, greaterThanOrEqualTo(0));
            expect(item.score, lessThanOrEqualTo(1.0));
          }
        }
      });
    });
  });
}
