import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/utils/input_mode_notifier.dart';

void main() {
  group('InputModeNotifier', () {
    late ProviderContainer container;
    late InputModeNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(inputModeProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('initial mode is mouse', () {
      expect(container.read(inputModeProvider), InputMode.mouse);
    });

    test('keyboard key press switches to keyboard mode', () {
      notifier.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
          timeStamp: Duration.zero,
        ),
      );
      expect(container.read(inputModeProvider), InputMode.keyboard);
    });

    test('gamepad button switches to gamepad mode', () {
      notifier.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.gameButtonA,
          logicalKey: LogicalKeyboardKey.gameButtonA,
          timeStamp: Duration.zero,
        ),
      );
      expect(container.read(inputModeProvider), InputMode.gamepad);
    });

    test('mouse hover event switches to mouse mode', () {
      // Switch to keyboard first.
      notifier.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
          timeStamp: Duration.zero,
        ),
      );
      expect(container.read(inputModeProvider), InputMode.keyboard);

      // Pointer hover switches back to mouse.
      notifier.onPointerEvent(
        const PointerHoverEvent(kind: PointerDeviceKind.mouse),
      );
      expect(container.read(inputModeProvider), InputMode.mouse);
    });

    test('touch event switches to touch mode', () {
      notifier.onPointerEvent(
        const PointerDownEvent(kind: PointerDeviceKind.touch),
      );
      expect(container.read(inputModeProvider), InputMode.touch);
    });

    test('key up events are ignored', () {
      // Set to mouse first, then send key up.
      notifier.onPointerEvent(
        const PointerHoverEvent(kind: PointerDeviceKind.mouse),
      );
      notifier.onKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
          timeStamp: Duration.zero,
        ),
      );
      // Should still be mouse.
      expect(container.read(inputModeProvider), InputMode.mouse);
    });

    test('showFocusIndicators returns true for '
        'keyboard and gamepad', () {
      expect(InputModeNotifier.showFocusIndicators(InputMode.keyboard), isTrue);
      expect(InputModeNotifier.showFocusIndicators(InputMode.gamepad), isTrue);
      expect(InputModeNotifier.showFocusIndicators(InputMode.mouse), isFalse);
      expect(InputModeNotifier.showFocusIndicators(InputMode.touch), isFalse);
    });

    test('all gamepad buttons are detected', () {
      final gamepadKeys = [
        LogicalKeyboardKey.gameButtonA,
        LogicalKeyboardKey.gameButtonB,
        LogicalKeyboardKey.gameButtonX,
        LogicalKeyboardKey.gameButtonY,
        LogicalKeyboardKey.gameButtonLeft1,
        LogicalKeyboardKey.gameButtonLeft2,
        LogicalKeyboardKey.gameButtonRight1,
        LogicalKeyboardKey.gameButtonRight2,
        LogicalKeyboardKey.gameButtonStart,
        LogicalKeyboardKey.gameButtonSelect,
        LogicalKeyboardKey.gameButtonMode,
        LogicalKeyboardKey.gameButtonThumbLeft,
        LogicalKeyboardKey.gameButtonThumbRight,
      ];

      for (final key in gamepadKeys) {
        // Reset to mouse.
        notifier.onPointerEvent(
          const PointerHoverEvent(kind: PointerDeviceKind.mouse),
        );
        expect(
          container.read(inputModeProvider),
          InputMode.mouse,
          reason:
              'Should be mouse before '
              '${key.debugName}',
        );

        notifier.onKeyEvent(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.gameButtonA,
            logicalKey: key,
            timeStamp: Duration.zero,
          ),
        );
        expect(
          container.read(inputModeProvider),
          InputMode.gamepad,
          reason:
              '${key.debugName} should trigger '
              'gamepad mode',
        );
      }
    });

    test('stylus input treated as touch', () {
      notifier.onPointerEvent(
        const PointerDownEvent(kind: PointerDeviceKind.stylus),
      );
      expect(container.read(inputModeProvider), InputMode.touch);
    });
  });
}
