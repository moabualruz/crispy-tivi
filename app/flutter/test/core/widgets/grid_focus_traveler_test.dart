import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/grid_focus_traveler.dart';

void main() {
  group('GridFocusTraveler widget', () {
    testWidgets('wraps child in FocusTraversalGroup', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GridFocusTraveler(crossAxisCount: 3, child: SizedBox()),
          ),
        ),
      );

      expect(find.byType(FocusTraversalGroup), findsAtLeast(1));
    });
  });

  group('GridFocusTravelerPolicy', () {
    test('can be instantiated with required params', () {
      final policy = GridFocusTravelerPolicy(crossAxisCount: 4);
      expect(policy.crossAxisCount, 4);
    });

    test('onChanged callback is optional', () {
      final policy = GridFocusTravelerPolicy(crossAxisCount: 3);
      expect(policy.onChanged, isNull);
    });

    test('onChanged callback is stored', () {
      int? lastIndex;
      final policy = GridFocusTravelerPolicy(
        crossAxisCount: 3,
        onChanged: (i) => lastIndex = i,
      );
      policy.onChanged?.call(5);
      expect(lastIndex, 5);
    });
  });
}
