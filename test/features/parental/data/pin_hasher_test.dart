import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/parental/domain/content_rating.dart';

void main() {
  group('CrispyBackend PIN hashing', () {
    late MemoryBackend backend;

    setUp(() {
      backend = MemoryBackend();
    });

    group('hashPin', () {
      test('produces 64-character hex string', () async {
        final hashed = await backend.hashPin('1234');

        expect(hashed.length, 64);
        expect(RegExp(r'^[a-f0-9]+$').hasMatch(hashed), isTrue);
      });

      test('is deterministic (same input -> same hash)', () async {
        final hash1 = await backend.hashPin('1234');
        final hash2 = await backend.hashPin('1234');

        expect(hash1, equals(hash2));
      });

      test('different inputs produce different hashes', () async {
        final hash1 = await backend.hashPin('1234');
        final hash2 = await backend.hashPin('5678');

        expect(hash1, isNot(equals(hash2)));
      });

      test('empty string produces valid hash', () async {
        final hashed = await backend.hashPin('');

        expect(hashed.length, 64);
      });
    });

    group('verifyPin', () {
      test('returns true for correct PIN', () async {
        final stored = await backend.hashPin('1234');

        expect(await backend.verifyPin('1234', stored), isTrue);
      });

      test('returns false for incorrect PIN', () async {
        final stored = await backend.hashPin('1234');

        expect(await backend.verifyPin('0000', stored), isFalse);
      });

      test('returns false for empty PIN against stored hash', () async {
        final stored = await backend.hashPin('1234');

        expect(await backend.verifyPin('', stored), isFalse);
      });
    });

    group('isHashedPin', () {
      test('returns true for valid SHA-256 hex string', () async {
        final hashed = await backend.hashPin('1234');

        expect(backend.isHashedPin(hashed), isTrue);
      });

      test('returns false for short string (plaintext PIN)', () {
        expect(backend.isHashedPin('1234'), isFalse);
      });

      test('returns false for non-hex 64-char string', () {
        final nonHex = 'z' * 64;

        expect(backend.isHashedPin(nonHex), isFalse);
      });

      test('returns false for empty string', () {
        expect(backend.isHashedPin(''), isFalse);
      });
    });
  });

  group('ContentRatingLevel', () {
    group('fromString', () {
      test('parses MPAA ratings', () {
        expect(ContentRatingLevel.fromString('G'), ContentRatingLevel.g);
        expect(ContentRatingLevel.fromString('PG'), ContentRatingLevel.pg);
        expect(ContentRatingLevel.fromString('PG-13'), ContentRatingLevel.pg13);
        expect(ContentRatingLevel.fromString('R'), ContentRatingLevel.r);
        expect(ContentRatingLevel.fromString('NC-17'), ContentRatingLevel.nc17);
      });

      test('parses TV ratings', () {
        expect(ContentRatingLevel.fromString('TV-G'), ContentRatingLevel.g);
        expect(ContentRatingLevel.fromString('TV-Y'), ContentRatingLevel.g);
        expect(ContentRatingLevel.fromString('TV-PG'), ContentRatingLevel.pg);
        expect(ContentRatingLevel.fromString('TV-14'), ContentRatingLevel.pg13);
        expect(ContentRatingLevel.fromString('TV-MA'), ContentRatingLevel.nc17);
      });

      test('handles case insensitivity', () {
        expect(ContentRatingLevel.fromString('pg-13'), ContentRatingLevel.pg13);
        expect(ContentRatingLevel.fromString('rated r'), ContentRatingLevel.r);
      });

      test('returns unrated for null or empty', () {
        expect(ContentRatingLevel.fromString(null), ContentRatingLevel.unrated);
        expect(ContentRatingLevel.fromString(''), ContentRatingLevel.unrated);
      });

      test('returns unrated for unknown rating', () {
        expect(
          ContentRatingLevel.fromString('UNKNOWN'),
          ContentRatingLevel.unrated,
        );
      });
    });

    group('isAllowedFor', () {
      test('G content allowed for PG max', () {
        expect(
          ContentRatingLevel.g.isAllowedFor(ContentRatingLevel.pg),
          isTrue,
        );
      });

      test('R content not allowed for PG max', () {
        expect(
          ContentRatingLevel.r.isAllowedFor(ContentRatingLevel.pg),
          isFalse,
        );
      });

      test('unrated content is always allowed', () {
        expect(
          ContentRatingLevel.unrated.isAllowedFor(ContentRatingLevel.g),
          isTrue,
        );
      });

      test('same rating is allowed', () {
        expect(
          ContentRatingLevel.pg13.isAllowedFor(ContentRatingLevel.pg13),
          isTrue,
        );
      });
    });

    group('fromValue', () {
      test('round-trips all values', () {
        for (final level in ContentRatingLevel.values) {
          expect(ContentRatingLevel.fromValue(level.value), level);
        }
      });

      test('returns unrated for unknown value', () {
        expect(ContentRatingLevel.fromValue(99), ContentRatingLevel.unrated);
      });
    });

    test('description returns non-empty string', () {
      for (final level in ContentRatingLevel.values) {
        expect(level.description, isNotEmpty);
      }
    });
  });
}
