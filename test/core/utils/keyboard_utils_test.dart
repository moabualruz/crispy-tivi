import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/utils/keyboard_utils.dart';

void main() {
  group('isTextFieldFocused', () {
    test('returns false when no widget has focus', () {
      expect(isTextFieldFocused(), isFalse);
    });
  });

  group('tryUnfocusTextFieldFirst', () {
    testWidgets('returns false when no text field is focused', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      );

      expect(tryUnfocusTextFieldFirst(), isFalse);
    });

    testWidgets('returns false when nothing has focus', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('hello'),
        ),
      );

      // No focus at all.
      expect(tryUnfocusTextFieldFirst(), isFalse);
    });

    testWidgets('returns true and unfocuses when EditableText has focus', (
      tester,
    ) async {
      final focusNode = FocusNode();
      final controller = TextEditingController();
      addTearDown(() {
        focusNode.dispose();
        controller.dispose();
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: EditableText(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 14),
            cursorColor: const Color(0xFF000000),
            backgroundCursorColor: const Color(0xFF000000),
          ),
        ),
      );

      // Give focus to the text field.
      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
      expect(tryUnfocusTextFieldFirst(), isTrue);

      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('returns false when a non-text Focus has primary focus', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Focus(focusNode: focusNode, child: const SizedBox()),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Not a text field, so should return false.
      expect(tryUnfocusTextFieldFirst(), isFalse);
    });
  });
}
