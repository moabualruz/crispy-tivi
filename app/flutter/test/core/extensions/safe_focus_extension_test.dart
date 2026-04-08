import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/extensions/safe_focus_extension.dart';

void main() {
  group('SafeFocusExtension', () {
    group('requestFocusSafely()', () {
      testWidgets('returns true and requests focus when node is attached', (
        tester,
      ) async {
        final node = FocusNode();
        await tester.pumpWidget(
          MaterialApp(home: Focus(focusNode: node, child: const SizedBox())),
        );

        final result = node.requestFocusSafely();
        await tester.pump();

        expect(result, isTrue);
        expect(node.hasFocus, isTrue);

        node.dispose();
      });

      test('returns false and does NOT throw when node has no context', () {
        // A FocusNode that was never attached to a widget tree
        // has context == null.
        final node = FocusNode();

        // Should not throw.
        final result = node.requestFocusSafely();
        expect(result, isFalse);

        node.dispose();
      });

      testWidgets('returns false when canRequestFocus is false', (
        tester,
      ) async {
        final node = FocusNode(canRequestFocus: false);
        await tester.pumpWidget(
          MaterialApp(home: Focus(focusNode: node, child: const SizedBox())),
        );

        final result = node.requestFocusSafely();
        expect(result, isFalse);

        node.dispose();
      });
    });
  });
}
