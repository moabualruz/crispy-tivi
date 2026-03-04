import 'package:crispy_tivi/core/widgets/focus_wrapper.dart';
import 'package:crispy_tivi/core/widgets/input_mode_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimum tree that FocusWrapper needs:
/// ProviderScope and InputModeScope.
Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    home: InputModeScope(
      showFocusIndicators: true,
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  group('FocusWrapper onKeyboardActivate', () {
    testWidgets('Enter fires onKeyboardActivate when set', (tester) async {
      var keyboardActivated = false;
      var selected = false;

      await tester.pumpWidget(
        _wrap(
          FocusWrapper(
            autofocus: true,
            onSelect: () => selected = true,
            onKeyboardActivate: () => keyboardActivated = true,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(keyboardActivated, isTrue);
      expect(selected, isFalse);
    });

    testWidgets(
      'Enter falls back to onSelect when onKeyboardActivate is null',
      (tester) async {
        var selected = false;

        await tester.pumpWidget(
          _wrap(
            FocusWrapper(
              autofocus: true,
              onSelect: () => selected = true,
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(selected, isTrue);
      },
    );

    testWidgets('GamepadA fires onKeyboardActivate when set', (tester) async {
      var keyboardActivated = false;
      var selected = false;

      await tester.pumpWidget(
        _wrap(
          FocusWrapper(
            autofocus: true,
            onSelect: () => selected = true,
            onKeyboardActivate: () => keyboardActivated = true,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pump();

      expect(keyboardActivated, isTrue);
      expect(selected, isFalse);
    });

    testWidgets('Mouse tap fires onSelect, not onKeyboardActivate', (
      tester,
    ) async {
      var keyboardActivated = false;
      var selected = false;

      await tester.pumpWidget(
        _wrap(
          FocusWrapper(
            onSelect: () => selected = true,
            onKeyboardActivate: () => keyboardActivated = true,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FocusWrapper));
      await tester.pump();

      expect(selected, isTrue);
      expect(keyboardActivated, isFalse);
    });

    testWidgets('Select key fires onKeyboardActivate when set', (tester) async {
      var keyboardActivated = false;

      await tester.pumpWidget(
        _wrap(
          FocusWrapper(
            autofocus: true,
            onKeyboardActivate: () => keyboardActivated = true,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(keyboardActivated, isTrue);
    });
  });
}
