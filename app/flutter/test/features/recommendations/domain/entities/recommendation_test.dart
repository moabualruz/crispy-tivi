import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/recommendations/'
    'domain/entities/recommendation.dart';

void main() {
  group('RecommendationReasonType', () {
    test('has exactly 6 values', () {
      expect(RecommendationReasonType.values.length, 6);
    });

    test('contains all expected values', () {
      expect(
        RecommendationReasonType.values,
        containsAll([
          RecommendationReasonType.becauseYouWatched,
          RecommendationReasonType.popularInGenre,
          RecommendationReasonType.trending,
          RecommendationReasonType.newForYou,
          RecommendationReasonType.topPick,
          RecommendationReasonType.coldStart,
        ]),
      );
    });
  });

  group('RecommendationReason', () {
    group('displayText', () {
      test('becauseYouWatched includes source item name', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.becauseYouWatched,
          sourceItemName: 'Action Movie',
        );
        expect(reason.displayText, 'Because you watched Action Movie');
      });

      test('becauseYouWatched handles null '
          'sourceItemName', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.becauseYouWatched,
        );
        expect(reason.displayText, 'Because you watched ');
      });

      test('popularInGenre includes genre name', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.popularInGenre,
          genreName: 'Action',
        );
        expect(reason.displayText, 'Popular in Action');
      });

      test('popularInGenre handles null genreName', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.popularInGenre,
        );
        expect(reason.displayText, 'Popular in ');
      });

      test('trending returns fixed text', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.trending,
        );
        expect(reason.displayText, 'Trending now');
      });

      test('newForYou returns fixed text', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.newForYou,
        );
        expect(reason.displayText, 'New for you');
      });

      test('topPick returns fixed text', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.topPick,
        );
        expect(reason.displayText, 'Top pick for you');
      });

      test('coldStart returns fixed text', () {
        const reason = RecommendationReason(
          type: RecommendationReasonType.coldStart,
        );
        expect(reason.displayText, 'Popular right now');
      });
    });

    group('equality', () {
      test('equal when type and fields match', () {
        const a = RecommendationReason(
          type: RecommendationReasonType.becauseYouWatched,
          sourceItemName: 'Movie A',
        );
        const b = RecommendationReason(
          type: RecommendationReasonType.becauseYouWatched,
          sourceItemName: 'Movie A',
        );
        expect(a, equals(b));
      });

      test('not equal when type differs', () {
        const a = RecommendationReason(type: RecommendationReasonType.trending);
        const b = RecommendationReason(type: RecommendationReasonType.topPick);
        expect(a, isNot(equals(b)));
      });

      test('not equal when sourceItemName differs', () {
        const a = RecommendationReason(
          type: RecommendationReasonType.becauseYouWatched,
          sourceItemName: 'Movie A',
        );
        const b = RecommendationReason(
          type: RecommendationReasonType.becauseYouWatched,
          sourceItemName: 'Movie B',
        );
        expect(a, isNot(equals(b)));
      });

      test('not equal when genreName differs', () {
        const a = RecommendationReason(
          type: RecommendationReasonType.popularInGenre,
          genreName: 'Action',
        );
        const b = RecommendationReason(
          type: RecommendationReasonType.popularInGenre,
          genreName: 'Comedy',
        );
        expect(a, isNot(equals(b)));
      });
    });

    group('hashCode', () {
      test('same for equal instances', () {
        const a = RecommendationReason(
          type: RecommendationReasonType.popularInGenre,
          genreName: 'Drama',
        );
        const b = RecommendationReason(
          type: RecommendationReasonType.popularInGenre,
          genreName: 'Drama',
        );
        expect(a.hashCode, equals(b.hashCode));
      });

      test('differs for unequal instances', () {
        const a = RecommendationReason(type: RecommendationReasonType.trending);
        const b = RecommendationReason(
          type: RecommendationReasonType.coldStart,
        );
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });
    });

    test('toString includes type and displayText', () {
      const reason = RecommendationReason(
        type: RecommendationReasonType.trending,
      );
      final str = reason.toString();
      expect(str, contains('trending'));
      expect(str, contains('Trending now'));
    });
  });

  group('Recommendation', () {
    const reason = RecommendationReason(type: RecommendationReasonType.topPick);

    Recommendation makeRec({
      String itemId = 'item1',
      String itemName = 'Test Movie',
      String mediaType = 'movie',
      RecommendationReason r = reason,
      double score = 0.85,
      String? posterUrl,
      String? category,
      String? streamUrl,
      String? rating,
      int? year,
      String? seriesId,
    }) {
      return Recommendation(
        itemId: itemId,
        itemName: itemName,
        mediaType: mediaType,
        reason: r,
        score: score,
        posterUrl: posterUrl,
        category: category,
        streamUrl: streamUrl,
        rating: rating,
        year: year,
        seriesId: seriesId,
      );
    }

    test('constructor stores all required fields', () {
      final rec = makeRec();
      expect(rec.itemId, 'item1');
      expect(rec.itemName, 'Test Movie');
      expect(rec.mediaType, 'movie');
      expect(rec.reason, reason);
      expect(rec.score, 0.85);
    });

    test('constructor stores all optional fields', () {
      final rec = makeRec(
        posterUrl: 'http://poster.jpg',
        category: 'Action',
        streamUrl: 'http://stream.m3u8',
        rating: '8.5',
        year: 2023,
        seriesId: 'series1',
      );
      expect(rec.posterUrl, 'http://poster.jpg');
      expect(rec.category, 'Action');
      expect(rec.streamUrl, 'http://stream.m3u8');
      expect(rec.rating, '8.5');
      expect(rec.year, 2023);
      expect(rec.seriesId, 'series1');
    });

    test('optional fields default to null', () {
      final rec = makeRec();
      expect(rec.posterUrl, isNull);
      expect(rec.category, isNull);
      expect(rec.streamUrl, isNull);
      expect(rec.rating, isNull);
      expect(rec.year, isNull);
      expect(rec.seriesId, isNull);
    });

    group('equality', () {
      test('equal when itemId and reason match', () {
        final a = makeRec(itemId: 'x', score: 0.5);
        final b = makeRec(itemId: 'x', score: 0.9);
        expect(a, equals(b));
      });

      test('not equal when itemId differs', () {
        final a = makeRec(itemId: 'x');
        final b = makeRec(itemId: 'y');
        expect(a, isNot(equals(b)));
      });

      test('not equal when reason differs', () {
        const reasonA = RecommendationReason(
          type: RecommendationReasonType.topPick,
        );
        const reasonB = RecommendationReason(
          type: RecommendationReasonType.trending,
        );
        final a = makeRec(r: reasonA);
        final b = makeRec(r: reasonB);
        expect(a, isNot(equals(b)));
      });

      test('equal ignores score difference', () {
        final a = makeRec(score: 0.1);
        final b = makeRec(score: 0.99);
        expect(a, equals(b));
      });
    });

    group('hashCode', () {
      test('consistent for equal instances', () {
        final a = makeRec(itemId: 'z', score: 0.3);
        final b = makeRec(itemId: 'z', score: 0.7);
        expect(a.hashCode, equals(b.hashCode));
      });

      test('differs for different itemId', () {
        final a = makeRec(itemId: 'a');
        final b = makeRec(itemId: 'b');
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });
    });

    test('toString includes name and score', () {
      final rec = makeRec(itemName: 'Cool Movie', score: 0.75);
      final str = rec.toString();
      expect(str, contains('Cool Movie'));
      expect(str, contains('0.75'));
    });

    test('toString includes reason displayText', () {
      final rec = makeRec(
        r: const RecommendationReason(type: RecommendationReasonType.trending),
      );
      final str = rec.toString();
      expect(str, contains('Trending now'));
    });
  });

  group('RecommendationSection', () {
    const reason = RecommendationReason(type: RecommendationReasonType.topPick);

    final sampleItems = [
      Recommendation(
        itemId: '1',
        itemName: 'Movie 1',
        mediaType: 'movie',
        reason: reason,
        score: 0.9,
      ),
      Recommendation(
        itemId: '2',
        itemName: 'Movie 2',
        mediaType: 'movie',
        reason: reason,
        score: 0.8,
      ),
    ];

    test('constructor stores all fields', () {
      final section = RecommendationSection(
        title: 'Top Picks for You',
        reasonType: RecommendationReasonType.topPick,
        items: sampleItems,
      );
      expect(section.title, 'Top Picks for You');
      expect(section.reasonType, RecommendationReasonType.topPick);
      expect(section.items, hasLength(2));
    });

    test('constructor works with empty items list', () {
      const section = RecommendationSection(
        title: 'Empty Section',
        reasonType: RecommendationReasonType.trending,
        items: [],
      );
      expect(section.items, isEmpty);
    });

    group('equality', () {
      test('equal when title and reasonType match', () {
        final a = RecommendationSection(
          title: 'Top Picks',
          reasonType: RecommendationReasonType.topPick,
          items: sampleItems,
        );
        final b = RecommendationSection(
          title: 'Top Picks',
          reasonType: RecommendationReasonType.topPick,
          items: [],
        );
        expect(a, equals(b));
      });

      test('not equal when title differs', () {
        const a = RecommendationSection(
          title: 'Top Picks',
          reasonType: RecommendationReasonType.topPick,
          items: [],
        );
        const b = RecommendationSection(
          title: 'Different',
          reasonType: RecommendationReasonType.topPick,
          items: [],
        );
        expect(a, isNot(equals(b)));
      });

      test('not equal when reasonType differs', () {
        const a = RecommendationSection(
          title: 'Same Title',
          reasonType: RecommendationReasonType.topPick,
          items: [],
        );
        const b = RecommendationSection(
          title: 'Same Title',
          reasonType: RecommendationReasonType.trending,
          items: [],
        );
        expect(a, isNot(equals(b)));
      });

      test('equality ignores items list difference', () {
        final a = RecommendationSection(
          title: 'Section',
          reasonType: RecommendationReasonType.coldStart,
          items: sampleItems,
        );
        const b = RecommendationSection(
          title: 'Section',
          reasonType: RecommendationReasonType.coldStart,
          items: [],
        );
        expect(a, equals(b));
      });
    });

    group('hashCode', () {
      test('consistent for equal instances', () {
        final a = RecommendationSection(
          title: 'Trending',
          reasonType: RecommendationReasonType.trending,
          items: sampleItems,
        );
        const b = RecommendationSection(
          title: 'Trending',
          reasonType: RecommendationReasonType.trending,
          items: [],
        );
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    test('toString includes title', () {
      final section = RecommendationSection(
        title: 'My Section',
        reasonType: RecommendationReasonType.newForYou,
        items: sampleItems,
      );
      final str = section.toString();
      expect(str, contains('My Section'));
    });

    test('toString includes item count', () {
      final section = RecommendationSection(
        title: 'My Section',
        reasonType: RecommendationReasonType.newForYou,
        items: sampleItems,
      );
      final str = section.toString();
      expect(str, contains('2 items'));
    });

    test('toString for empty section shows 0 items', () {
      const section = RecommendationSection(
        title: 'Empty',
        reasonType: RecommendationReasonType.coldStart,
        items: [],
      );
      expect(section.toString(), contains('0 items'));
    });
  });
}
