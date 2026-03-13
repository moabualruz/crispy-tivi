import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/safe_focus_scope.dart';

void main() {
  group('SafeFocusScope', () {
    testWidgets('renders child widget correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SafeFocusScope(child: Text('Hello'))),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(FocusScope), findsWidgets);
    });

    testWidgets('stores restorationKey when provided', (tester) async {
      const testKey = 'test-route-key';
      await tester.pumpWidget(
        const MaterialApp(
          home: SafeFocusScope(
            restorationKey: testKey,
            child: Text('With Key'),
          ),
        ),
      );

      expect(find.text('With Key'), findsOneWidget);
      // Widget tree should contain a SafeFocusScope with the
      // restorationKey property.
      final safeFocusScope = tester.widget<SafeFocusScope>(
        find.byType(SafeFocusScope),
      );
      expect(safeFocusScope.restorationKey, equals(testKey));
    });

    testWidgets('autofocus requests focus on the scope when true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SafeFocusScope(autofocus: true, child: Text('Autofocused')),
        ),
      );
      await tester.pumpAndSettle();

      // The FocusScope created by SafeFocusScope should have focus.
      final focusScope = tester.widget<FocusScope>(
        find.byType(FocusScope).last,
      );
      expect(focusScope.autofocus, isTrue);
    });
  });
}
