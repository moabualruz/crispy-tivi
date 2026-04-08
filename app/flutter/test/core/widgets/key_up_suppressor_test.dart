import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/key_up_suppressor.dart';

/// Creates a fake [KeyDownEvent] for the given key.
KeyDownEvent _keyDown(LogicalKeyboardKey key) => KeyDownEvent(
  logicalKey: key,
  physicalKey: PhysicalKeyboardKey.enter,
  timeStamp: Duration.zero,
);

/// Creates a fake [KeyUpEvent] for the given key.
KeyUpEvent _keyUp(LogicalKeyboardKey key) => KeyUpEvent(
  logicalKey: key,
  physicalKey: PhysicalKeyboardKey.enter,
  timeStamp: Duration.zero,
);

void main() {
  group('SelectKeyUpSuppressor', () {
    setUp(SelectKeyUpSuppressor.clearSuppression);

    test('does not consume when not suppressed', () {
      final event = _keyUp(LogicalKeyboardKey.enter);
      expect(SelectKeyUpSuppressor.consumeIfSuppressed(event), isFalse);
    });

    test('consumes select key-up when suppressed', () {
      SelectKeyUpSuppressor.suppressSelectUntilKeyUp();

      // Key-down should be consumed while suppressed.
      final down = _keyDown(LogicalKeyboardKey.enter);
      expect(SelectKeyUpSuppressor.consumeIfSuppressed(down), isTrue);

      // Key-up consumes and clears suppression.
      final up = _keyUp(LogicalKeyboardKey.enter);
      expect(SelectKeyUpSuppressor.consumeIfSuppressed(up), isTrue);

      // After clear, no longer consumed.
      final next = _keyUp(LogicalKeyboardKey.enter);
      expect(SelectKeyUpSuppressor.consumeIfSuppressed(next), isFalse);
    });

    test('does not consume non-select keys when suppressed', () {
      SelectKeyUpSuppressor.suppressSelectUntilKeyUp();

      final event = _keyUp(LogicalKeyboardKey.arrowUp);
      expect(SelectKeyUpSuppressor.consumeIfSuppressed(event), isFalse);
    });

    test('consumes gameButtonA as select key', () {
      SelectKeyUpSuppressor.suppressSelectUntilKeyUp();

      final event = _keyUp(LogicalKeyboardKey.gameButtonA);
      expect(SelectKeyUpSuppressor.consumeIfSuppressed(event), isTrue);
    });
  });

  group('BackKeyUpSuppressor', () {
    setUp(BackKeyUpSuppressor.clearSuppression);

    test('does not consume when not suppressed', () {
      final event = _keyUp(LogicalKeyboardKey.escape);
      expect(BackKeyUpSuppressor.consumeIfSuppressed(event), isFalse);
    });

    test('consumes escape key-up when suppressed', () {
      BackKeyUpSuppressor.suppressBackUntilKeyUp();

      final up = _keyUp(LogicalKeyboardKey.escape);
      expect(BackKeyUpSuppressor.consumeIfSuppressed(up), isTrue);

      // Suppression cleared after key-up.
      final next = _keyUp(LogicalKeyboardKey.escape);
      expect(BackKeyUpSuppressor.consumeIfSuppressed(next), isFalse);
    });

    test('consumes goBack key-up when suppressed', () {
      BackKeyUpSuppressor.suppressBackUntilKeyUp();

      final up = _keyUp(LogicalKeyboardKey.goBack);
      expect(BackKeyUpSuppressor.consumeIfSuppressed(up), isTrue);
    });

    test('consumes gameButtonB as back key', () {
      BackKeyUpSuppressor.suppressBackUntilKeyUp();

      final up = _keyUp(LogicalKeyboardKey.gameButtonB);
      expect(BackKeyUpSuppressor.consumeIfSuppressed(up), isTrue);
    });

    test('clearSuppression prevents consumption', () {
      BackKeyUpSuppressor.suppressBackUntilKeyUp();
      BackKeyUpSuppressor.clearSuppression();

      final up = _keyUp(LogicalKeyboardKey.escape);
      expect(BackKeyUpSuppressor.consumeIfSuppressed(up), isFalse);
    });
  });
}
