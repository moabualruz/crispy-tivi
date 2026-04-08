import 'package:crispy_tivi/core/widgets/responsive_layout.dart';
import 'package:crispy_tivi/core/widgets/safe_focus_scope.dart';
import 'package:crispy_tivi/core/widgets/screen_template.dart';
import 'package:crispy_tivi/core/widgets/tv_color_button_handler.dart';
import 'package:crispy_tivi/core/widgets/tv_color_button_legend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp({required Widget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('ScreenTemplate', () {
    testWidgets(
      'composes SafeFocusScope > FocusTraversalGroup > ResponsiveLayout',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            child: const ScreenTemplate(
              compactBody: Text('compact'),
              largeBody: Text('large'),
            ),
          ),
        );

        // Find widgets scoped to ScreenTemplate's subtree
        final screenTemplate = find.byType(ScreenTemplate);
        expect(screenTemplate, findsOneWidget);

        final safeFocusScope = find.descendant(
          of: screenTemplate,
          matching: find.byType(SafeFocusScope),
        );
        expect(safeFocusScope, findsOneWidget);

        final focusGroup = find.descendant(
          of: screenTemplate,
          matching: find.byType(FocusTraversalGroup),
        );
        expect(focusGroup, findsWidgets); // at least 1

        expect(
          find.descendant(
            of: screenTemplate,
            matching: find.byType(ResponsiveLayout),
          ),
          findsOneWidget,
        );

        // Verify nesting: SafeFocusScope is ancestor of ResponsiveLayout
        final responsive = find.byType(ResponsiveLayout);
        expect(
          find.ancestor(of: responsive, matching: find.byType(SafeFocusScope)),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders compactBody at compact breakpoint', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const ScreenTemplate(
            compactBody: Text('compact'),
            largeBody: Text('large'),
          ),
        ),
      );

      expect(find.text('compact'), findsOneWidget);
      expect(find.text('large'), findsNothing);
    });

    testWidgets('renders largeBody at large breakpoint', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const ScreenTemplate(
            compactBody: Text('compact'),
            largeBody: Text('large'),
          ),
        ),
      );

      expect(find.text('large'), findsOneWidget);
      expect(find.text('compact'), findsNothing);
    });

    testWidgets('mediumBody=null falls back to compactBody', (tester) async {
      tester.view.physicalSize = const Size(700, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const ScreenTemplate(
            compactBody: Text('compact'),
            largeBody: Text('large'),
          ),
        ),
      );

      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('passes focusRestorationKey to SafeFocusScope', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const ScreenTemplate(
            compactBody: Text('compact'),
            largeBody: Text('large'),
            focusRestorationKey: 'test-key',
          ),
        ),
      );

      final safeFocusScope = tester.widget<SafeFocusScope>(
        find.byType(SafeFocusScope),
      );
      expect(safeFocusScope.restorationKey, 'test-key');
    });

    testWidgets(
      'renders TvColorButtonLegend when colorButtonMap provided at large breakpoint',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestApp(
            child: ScreenTemplate(
              compactBody: const Text('compact'),
              largeBody: const Text('large'),
              colorButtonMap: {
                TvColorButton.red: ColorButtonAction(
                  label: 'Delete',
                  onPressed: () {},
                ),
              },
            ),
          ),
        );

        expect(find.byType(TvColorButtonLegend), findsOneWidget);
        expect(find.byType(TvColorButtonHandler), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      },
    );

    testWidgets('does NOT include Scaffold', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const ScreenTemplate(
            compactBody: Text('compact'),
            largeBody: Text('large'),
          ),
        ),
      );

      // The buildTestApp already has a Scaffold, so there should be
      // exactly 1 Scaffold (the test wrapper), not 2.
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ScreenTemplate is a StatelessWidget (not base class)', (
      tester,
    ) async {
      const template = ScreenTemplate(
        compactBody: Text('compact'),
        largeBody: Text('large'),
      );

      expect(template, isA<StatelessWidget>());
    });
  });

  group('TvColorButtonLegend', () {
    testWidgets('renders colored dots with labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvColorButtonLegend(
              colorButtonMap: {
                TvColorButton.red: ColorButtonAction(
                  label: 'Delete',
                  onPressed: () {},
                ),
                TvColorButton.green: ColorButtonAction(
                  label: 'Add',
                  onPressed: () {},
                ),
                TvColorButton.yellow: ColorButtonAction(
                  label: 'Edit',
                  onPressed: () {},
                ),
                TvColorButton.blue: ColorButtonAction(
                  label: 'Info',
                  onPressed: () {},
                ),
              },
            ),
          ),
        ),
      );

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
    });
  });

  group('TvColorButtonHandler', () {
    testWidgets('dispatches F1 key to red button action', (tester) async {
      var redPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvColorButtonHandler(
              colorButtonMap: {
                TvColorButton.red: ColorButtonAction(
                  label: 'Delete',
                  onPressed: () => redPressed = true,
                ),
              },
              child: const Focus(autofocus: true, child: Text('content')),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      expect(redPressed, isTrue);
    });

    testWidgets('dispatches F2 to green, F3 to yellow, F4 to blue', (
      tester,
    ) async {
      var greenPressed = false;
      var yellowPressed = false;
      var bluePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvColorButtonHandler(
              colorButtonMap: {
                TvColorButton.green: ColorButtonAction(
                  label: 'Add',
                  onPressed: () => greenPressed = true,
                ),
                TvColorButton.yellow: ColorButtonAction(
                  label: 'Edit',
                  onPressed: () => yellowPressed = true,
                ),
                TvColorButton.blue: ColorButtonAction(
                  label: 'Info',
                  onPressed: () => bluePressed = true,
                ),
              },
              child: const Focus(autofocus: true, child: Text('content')),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      expect(greenPressed, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      expect(yellowPressed, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      expect(bluePressed, isTrue);
    });
  });
}
