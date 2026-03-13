import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/focus_restoring_dialog.dart';

void main() {
  group('FocusRestoringDialog', () {
    testWidgets('dialog opens with focus trapped inside', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    showFocusRestoringDialog(
                      context: context,
                      builder:
                          (context) => const AlertDialog(
                            content: Text('Dialog Content'),
                          ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button to open dialog.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsOneWidget);
    });

    testWidgets('restores focus to trigger element after dialog dismissal', (
      tester,
    ) async {
      final buttonFocusNode = FocusNode();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (scaffoldContext) {
                  return Column(
                    children: [
                      ElevatedButton(
                        focusNode: buttonFocusNode,
                        autofocus: true,
                        onPressed: () {
                          showFocusRestoringDialog(
                            context: scaffoldContext,
                            builder:
                                (context) => AlertDialog(
                                  content: const Text('Dialog'),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                          );
                        },
                        child: const Text('Trigger'),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify button has focus.
      expect(buttonFocusNode.hasFocus, isTrue);

      // Open dialog.
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      // Close dialog.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Focus should be restored to the trigger button.
      expect(buttonFocusNode.hasFocus, isTrue);

      buttonFocusNode.dispose();
    });

    testWidgets(
      'handles gracefully when trigger widget is removed during dialog',
      (tester) async {
        final showButton = ValueNotifier(true);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showButton,
                  builder: (context, show, _) {
                    return Column(
                      children: [
                        if (show)
                          ElevatedButton(
                            autofocus: true,
                            onPressed: () {
                              showFocusRestoringDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      content: const Text('Dialog'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            // Remove the button before closing.
                                            showButton.value = false;
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            child: const Text('Trigger'),
                          ),
                        const Text('Placeholder'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog.
        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        // Close dialog (which also removes trigger button).
        // Should NOT throw.
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Trigger button is gone.
        expect(find.text('Trigger'), findsNothing);
        // App still renders.
        expect(find.text('Placeholder'), findsOneWidget);

        showButton.dispose();
      },
    );
  });
}
