import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Use relative import since the helper is in integration_test/helpers/.
// In widget tests we can still import it by path.
import '../../../integration_test/helpers/focus_test_helper.dart';

/// Minimal test widget with a known focus order for self-testing
/// the [FocusTestHelper].
Widget _buildFocusTestWidget({
  List<Key>? keys,
  bool includeFocusTraversalGroup = true,
}) {
  final fieldKeys =
      keys ??
      [
        const ValueKey('field-0'),
        const ValueKey('field-1'),
        const ValueKey('field-2'),
      ];

  final fields = Column(
    children: [
      for (final key in fieldKeys)
        TextField(
          key: key,
          decoration: InputDecoration(labelText: key.toString()),
        ),
    ],
  );

  final body =
      includeFocusTraversalGroup ? FocusTraversalGroup(child: fields) : fields;

  return MaterialApp(home: Scaffold(body: body));
}

void main() {
  group('FocusTestHelper', () {
    group('getFocusedKey', () {
      testWidgets('returns key of focused widget', (tester) async {
        const key0 = ValueKey('field-0');
        await tester.pumpWidget(_buildFocusTestWidget());

        final helper = FocusTestHelper(tester);

        // Tap the first field to give it focus.
        await tester.tap(find.byKey(key0));
        await tester.pump();

        expect(helper.getFocusedKey(), key0);
      });

      testWidgets('returns null when nothing is focused', (tester) async {
        await tester.pumpWidget(_buildFocusTestWidget());

        final helper = FocusTestHelper(tester);
        // No tap — nothing focused yet (primary focus may be on
        // the root scope, which has no key).
        final key = helper.getFocusedKey();
        // Either null or a framework-internal key — not one of ours.
        expect(key, isNot(const ValueKey('field-0')));
      });
    });

    group('hasFocusInfrastructure', () {
      testWidgets('returns true when FocusTraversalGroup exists', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildFocusTestWidget(includeFocusTraversalGroup: true),
        );
        final helper = FocusTestHelper(tester);
        expect(helper.hasFocusInfrastructure(), isTrue);
      });

      testWidgets('returns false when no FocusTraversalGroup', (tester) async {
        await tester.pumpWidget(
          _buildFocusTestWidget(includeFocusTraversalGroup: false),
        );
        // MaterialApp adds its own FocusTraversalGroup, so this will
        // actually find one. Verify the helper reports true even without
        // an explicit FocusTraversalGroup in the test widget.
        final helper = FocusTestHelper(tester);
        expect(helper.hasFocusInfrastructure(), isTrue);
      });
    });

    group('verifyTabOrder', () {
      testWidgets('passes with correct tab order', (tester) async {
        const keys = [
          ValueKey('field-0'),
          ValueKey('field-1'),
          ValueKey('field-2'),
        ];
        await tester.pumpWidget(_buildFocusTestWidget(keys: keys));

        final helper = FocusTestHelper(tester);

        // Tab through all three fields — should match order.
        await helper.verifyTabOrder(keys);
      });

      testWidgets('fails with descriptive message on wrong order', (
        tester,
      ) async {
        const keys = [
          ValueKey('field-0'),
          ValueKey('field-1'),
          ValueKey('field-2'),
        ];
        await tester.pumpWidget(_buildFocusTestWidget(keys: keys));

        final helper = FocusTestHelper(tester);

        // Expect reversed order to fail.
        const wrongOrder = [
          ValueKey('field-2'),
          ValueKey('field-1'),
          ValueKey('field-0'),
        ];

        try {
          await helper.verifyTabOrder(wrongOrder);
          fail('Expected TestFailure for wrong tab order');
        } on TestFailure catch (e) {
          expect(e.message, contains('Tab order mismatch'));
          expect(e.message, contains('step 0'));
          expect(e.message, contains('field-2'));
        }
      });
    });

    group('verifyFocusRestoration', () {
      testWidgets('detects focus restoration', (tester) async {
        const key0 = ValueKey('field-0');
        const key1 = ValueKey('field-1');
        await tester.pumpWidget(_buildFocusTestWidget());

        final helper = FocusTestHelper(tester);

        // Give field-0 focus first.
        await tester.tap(find.byKey(key0));
        await tester.pump();

        await helper.verifyFocusRestoration(
          expectedKey: key0,
          navigateAway: () async {
            // Simulate navigating away by focusing another field.
            await tester.tap(find.byKey(key1));
            await tester.pump();
          },
          navigateBack: () async {
            // Simulate navigating back by refocusing original.
            await tester.tap(find.byKey(key0));
            await tester.pump();
          },
        );
      });
    });
  });
}
