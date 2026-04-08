import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reusable focus-testing utility for integration and widget tests.
///
/// Provides methods to verify tab order, escape behavior, and focus
/// restoration across navigation. Works with any [WidgetTester] —
/// no backend dependency.
class FocusTestHelper {
  /// Creates a [FocusTestHelper] bound to the given [tester].
  const FocusTestHelper(this.tester);

  /// The [WidgetTester] used for keyboard simulation and pumping.
  final WidgetTester tester;

  /// Returns the [Key] of the currently focused widget, or `null`
  /// if nothing has focus or no [ValueKey] ancestor is found.
  ///
  /// Walks up the element tree from the focused node to find the
  /// nearest ancestor with a [ValueKey]. Skips framework-internal
  /// keys (e.g. [LabeledGlobalKey] on [EditableText]) so that
  /// the returned key matches what was assigned in app code.
  Key? getFocusedKey() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return null;
    final context = primaryFocus.context;
    if (context == null) return null;

    // Check the focus node's own widget first.
    final directKey = context.widget.key;
    if (directKey is ValueKey) return directKey;

    // Walk up to find the nearest ValueKey ancestor.
    Key? found;
    context.visitAncestorElements((element) {
      final key = element.widget.key;
      if (key is ValueKey) {
        found = key;
        return false; // stop walking
      }
      return true; // continue
    });
    return found;
  }

  /// Whether the current widget tree contains a
  /// [FocusTraversalPolicy] (indicating focus infrastructure
  /// is set up).
  ///
  /// Prints a diagnostic message via [debugPrint] when no policy
  /// is found — helps diagnose why tab traversal tests fail.
  bool hasFocusInfrastructure() {
    final finder = find.byWidgetPredicate(
      (widget) => widget is FocusTraversalGroup,
    );
    if (finder.evaluate().isEmpty) {
      debugPrint(
        'FocusTestHelper: No FocusTraversalGroup found in widget '
        'tree. Tab traversal tests may not work correctly.',
      );
      return false;
    }
    return true;
  }

  /// Verifies that pressing Tab cycles focus through the given
  /// [expectedOrder] of widget keys.
  ///
  /// Sends one Tab key event per expected key, pumping the frame
  /// between each. Throws a descriptive error if focus does not
  /// land on the expected key at any step.
  ///
  /// Uses [tester.pump] (not [pumpAndSettle]) to avoid timing
  /// issues with animations.
  Future<void> verifyTabOrder(List<Key> expectedOrder) async {
    for (var i = 0; i < expectedOrder.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final actualKey = getFocusedKey();
      final expected = expectedOrder[i];
      if (actualKey != expected) {
        throw TestFailure(
          'Tab order mismatch at step $i: '
          'expected key=$expected, '
          'got key=$actualKey. '
          'Full expected order: $expectedOrder',
        );
      }
    }
  }

  /// Verifies that pressing Escape causes [currentScreen] to no
  /// longer be found in the widget tree.
  ///
  /// Pumps up to [timeout] after the Escape event to allow async
  /// navigation to complete.
  Future<void> verifyEscapeExits({
    required Finder currentScreen,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // Confirm screen is present before pressing Escape.
    expect(
      currentScreen,
      findsOneWidget,
      reason: 'Screen should be present before Escape',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);

    // Pump with timeout to allow async navigation.
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (currentScreen.evaluate().isEmpty) return;
    }

    throw TestFailure(
      'Screen still present after Escape + ${timeout.inMilliseconds}ms: '
      '$currentScreen',
    );
  }

  /// Verifies that focus returns to [expectedKey] after
  /// navigating away and back.
  ///
  /// 1. Confirms [expectedKey] has focus (or requests it).
  /// 2. Calls [navigateAway].
  /// 3. Calls [navigateBack].
  /// 4. Verifies focus is restored to [expectedKey].
  Future<void> verifyFocusRestoration({
    required Key expectedKey,
    required Future<void> Function() navigateAway,
    required Future<void> Function() navigateBack,
  }) async {
    // Verify starting focus.
    final startKey = getFocusedKey();
    if (startKey != expectedKey) {
      // Try to focus the expected widget.
      final finder = find.byKey(expectedKey);
      expect(
        finder,
        findsOneWidget,
        reason: 'Widget with key=$expectedKey must exist for focus test',
      );
      await tester.tap(finder);
      await tester.pump();
    }

    await navigateAway();
    await tester.pump();

    await navigateBack();
    await tester.pump();

    final restoredKey = getFocusedKey();
    if (restoredKey != expectedKey) {
      throw TestFailure(
        'Focus not restored after navigation: '
        'expected key=$expectedKey, '
        'got key=$restoredKey',
      );
    }
  }
}
