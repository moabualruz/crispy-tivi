import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/parental/domain/content_rating.dart';

void main() {
  group('ContentRatingLevel Enum Tests', () {
    test('fromString parses MPAA ratings correctly', () {
      expect(ContentRatingLevel.fromString('G'), ContentRatingLevel.g);
      expect(ContentRatingLevel.fromString('PG'), ContentRatingLevel.pg);
      expect(ContentRatingLevel.fromString('PG-13'), ContentRatingLevel.pg13);
      expect(ContentRatingLevel.fromString('R'), ContentRatingLevel.r);
      expect(ContentRatingLevel.fromString('NC-17'), ContentRatingLevel.nc17);
    });

    test('fromString parses TV ratings correctly', () {
      expect(ContentRatingLevel.fromString('TV-Y'), ContentRatingLevel.g);
      expect(ContentRatingLevel.fromString('TV-G'), ContentRatingLevel.g);
      expect(ContentRatingLevel.fromString('TV-PG'), ContentRatingLevel.pg);
      expect(ContentRatingLevel.fromString('TV-14'), ContentRatingLevel.pg13);
      expect(ContentRatingLevel.fromString('TV-MA'), ContentRatingLevel.nc17);
    });

    test('fromString handles edge cases and unrecognized formats', () {
      expect(ContentRatingLevel.fromString(''), ContentRatingLevel.unrated);
      expect(ContentRatingLevel.fromString('   '), ContentRatingLevel.unrated);
      expect(ContentRatingLevel.fromString(null), ContentRatingLevel.unrated);
      expect(
        ContentRatingLevel.fromString('RANDOM'),
        ContentRatingLevel.unrated,
      );
      expect(ContentRatingLevel.fromString('RATED R'), ContentRatingLevel.r);
    });

    test('isAllowedFor logic respects hierarchy', () {
      // G is allowed for PG-13
      expect(
        ContentRatingLevel.g.isAllowedFor(ContentRatingLevel.pg13),
        isTrue,
      );
      // R is not allowed for PG-13
      expect(
        ContentRatingLevel.r.isAllowedFor(ContentRatingLevel.pg13),
        isFalse,
      );
      // Same rating is allowed
      expect(ContentRatingLevel.pg.isAllowedFor(ContentRatingLevel.pg), isTrue);
      // Unrated follows max allowed
      expect(
        ContentRatingLevel.unrated.isAllowedFor(ContentRatingLevel.g),
        isTrue,
      );
      expect(
        ContentRatingLevel.unrated.isAllowedFor(ContentRatingLevel.r),
        isTrue,
      );
    });

    test('fromValue mapping', () {
      expect(ContentRatingLevel.fromValue(0), ContentRatingLevel.g);
      expect(ContentRatingLevel.fromValue(4), ContentRatingLevel.nc17);
      expect(
        ContentRatingLevel.fromValue(99),
        ContentRatingLevel.unrated,
      ); // unknown returns unrated
    });
  });

  group('ContentRatingLevel.displayLabel', () {
    test('nc17 returns All / Unrestricted', () {
      expect(ContentRatingLevel.nc17.displayLabel, 'All / Unrestricted');
    });

    test('g returns code and description', () {
      expect(ContentRatingLevel.g.displayLabel, 'G — General Audiences');
    });

    test('pg returns code and description', () {
      expect(
        ContentRatingLevel.pg.displayLabel,
        'PG — Parental Guidance Suggested',
      );
    });

    test('pg13 returns code and description', () {
      expect(
        ContentRatingLevel.pg13.displayLabel,
        'PG-13 — Parents Strongly Cautioned',
      );
    });

    test('r returns code and description', () {
      expect(ContentRatingLevel.r.displayLabel, 'R — Restricted');
    });

    test('unrated returns code and description', () {
      expect(ContentRatingLevel.unrated.displayLabel, 'Unrated — Not Rated');
    });
  });
}
