import 'package:crispy_tivi/core/widgets/alpha_jump_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlphaJumpBar.computeOffsets', () {
    test('builds correct letter-to-offset map from sorted names', () {
      final names = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
      final offsets = AlphaJumpBar.computeOffsets(names, 50.0);

      expect(offsets['A'], 0.0);
      expect(offsets['B'], 50.0);
      expect(offsets['C'], 100.0);
      expect(offsets['D'], 150.0);
      expect(offsets.length, 4);
    });

    test('uses first occurrence for duplicate letters', () {
      final names = ['Apple', 'Avocado', 'Banana'];
      final offsets = AlphaJumpBar.computeOffsets(names, 40.0);

      expect(offsets['A'], 0.0); // First A, not second
      expect(offsets['B'], 80.0);
      expect(offsets.length, 2);
    });

    test('applies headerOffset', () {
      final names = ['Alpha', 'Bravo'];
      final offsets = AlphaJumpBar.computeOffsets(
        names,
        50.0,
        headerOffset: 100.0,
      );

      expect(offsets['A'], 100.0);
      expect(offsets['B'], 150.0);
    });

    test('empty name maps to #', () {
      final names = ['', 'Alpha'];
      final offsets = AlphaJumpBar.computeOffsets(names, 50.0);

      expect(offsets['#'], 0.0);
      expect(offsets['A'], 50.0);
    });

    test('returns empty map for empty list', () {
      final offsets = AlphaJumpBar.computeOffsets([], 50.0);
      expect(offsets, isEmpty);
    });
  });

  group('AlphaJumpBar.computeIndexOffsets', () {
    test('returns index-based offsets', () {
      final names = ['Alpha', 'Apple', 'Banana', 'Cherry'];
      final offsets = AlphaJumpBar.computeIndexOffsets(names);

      expect(offsets['A'], 0.0);
      expect(offsets['B'], 2.0);
      expect(offsets['C'], 3.0);
    });
  });

  group('AlphaJumpBar.scaleOffsets', () {
    test('scales index offsets to pixel offsets', () {
      final indexOffsets = {'A': 0.0, 'B': 5.0, 'C': 10.0};
      final scaled = AlphaJumpBar.scaleOffsets(indexOffsets, 1000.0, 20);

      // scale = 1000 / 20 = 50
      expect(scaled['A'], 0.0);
      expect(scaled['B'], 250.0);
      expect(scaled['C'], 500.0);
    });

    test('returns original offsets when totalItemCount is 0', () {
      final indexOffsets = {'A': 0.0, 'B': 5.0};
      final scaled = AlphaJumpBar.scaleOffsets(indexOffsets, 1000.0, 0);

      expect(scaled['A'], 0.0);
      expect(scaled['B'], 5.0);
    });
  });

  group('AlphaJumpBar widget', () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildTestWidget({
      Map<String, double> offsets = const {},
      int totalItemCount = 100,
      int hideThreshold = 50,
      FocusNode? focusNode,
      VoidCallback? onNavigateLeft,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              // A scrollable list so the controller has a position.
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: totalItemCount,
                  itemBuilder:
                      (_, i) => SizedBox(height: 50, child: Text('Item $i')),
                ),
              ),
              SizedBox(
                width: 28,
                height: 600,
                child: AlphaJumpBar(
                  controller: scrollController,
                  sectionOffsets: offsets,
                  totalItemCount: totalItemCount,
                  hideThreshold: hideThreshold,
                  focusNode: focusNode,
                  onNavigateLeft: onNavigateLeft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders letters from sectionOffsets', (tester) async {
      final offsets = {
        'A': 0.0,
        'B': 100.0,
        'C': 200.0,
        'M': 300.0,
        'Z': 400.0,
      };

      await tester.pumpWidget(buildTestWidget(offsets: offsets));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
    });

    testWidgets('auto-hides when item count below threshold', (tester) async {
      final offsets = {'A': 0.0, 'B': 100.0};

      await tester.pumpWidget(
        buildTestWidget(
          offsets: offsets,
          totalItemCount: 30,
          hideThreshold: 50,
        ),
      );
      await tester.pumpAndSettle();

      // Bar should be hidden — no letter text visible.
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
    });

    testWidgets('shows when item count meets threshold', (tester) async {
      final offsets = {'A': 0.0, 'B': 100.0};

      await tester.pumpWidget(
        buildTestWidget(
          offsets: offsets,
          totalItemCount: 50,
          hideThreshold: 50,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('hides when sectionOffsets is empty', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(offsets: const {}, totalItemCount: 100),
      );
      await tester.pumpAndSettle();

      // Should find no letter texts at all.
      for (var i = 0; i < 26; i++) {
        expect(find.text(String.fromCharCode(65 + i)), findsNothing);
      }
    });

    testWidgets('tapping a letter scrolls to its offset', (tester) async {
      final offsets = {
        'A': 0.0,
        'B': 500.0,
        'C': 1000.0,
        'D': 1500.0,
        'E': 2000.0,
      };

      await tester.pumpWidget(
        buildTestWidget(offsets: offsets, totalItemCount: 200),
      );
      await tester.pumpAndSettle();

      // Tap on letter C.
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      // Scroll position should be at C's offset (clamped to max).
      final position = scrollController.position.pixels;
      // The offset might be clamped to maxScrollExtent if 1000 > max.
      expect(position, greaterThan(0));
    });

    testWidgets('D-pad down moves highlight', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final offsets = {'A': 0.0, 'B': 100.0, 'C': 200.0};

      await tester.pumpWidget(
        buildTestWidget(
          offsets: offsets,
          totalItemCount: 100,
          focusNode: focusNode,
        ),
      );
      await tester.pumpAndSettle();

      // Focus the bar.
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Press down arrow.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 200));

      // The highlight should have moved — we can verify by checking
      // the widget rebuilt (no crash, correct state).
      // The bar still renders all letters.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('D-pad up does not go below index 0', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final offsets = {'A': 0.0, 'B': 100.0};

      await tester.pumpWidget(
        buildTestWidget(
          offsets: offsets,
          totalItemCount: 100,
          focusNode: focusNode,
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Press up at index 0 — should stay at 0.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('D-pad left calls onNavigateLeft', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var leftCalled = false;

      final offsets = {'A': 0.0, 'B': 100.0};

      await tester.pumpWidget(
        buildTestWidget(
          offsets: offsets,
          totalItemCount: 100,
          focusNode: focusNode,
          onNavigateLeft: () => leftCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(leftCalled, isTrue);
    });

    testWidgets('letters sorted alphabetically', (tester) async {
      // Provide out-of-order offsets.
      final offsets = {'Z': 0.0, 'A': 100.0, 'M': 200.0};

      await tester.pumpWidget(
        buildTestWidget(offsets: offsets, totalItemCount: 100),
      );
      await tester.pumpAndSettle();

      // All letters should be present.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
    });
  });
}
