import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/settings/presentation/'
    'widgets/tls_toggle_widget.dart';

void main() {
  group('TlsToggleWidget', () {
    testWidgets('renders with correct initial state when enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TlsToggleWidget(value: true, onChanged: (_) {})),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accept self-signed certificates'), findsOneWidget);
      expect(
        find.text(
          'Allows connections to servers with '
          'invalid TLS certificates',
        ),
        findsOneWidget,
      );

      // Switch should be ON.
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('renders with correct initial state when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TlsToggleWidget(value: false, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('toggling ON (disabling TLS) shows confirmation dialog', (
      tester,
    ) async {
      bool? callbackValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TlsToggleWidget(
              value: false,
              onChanged: (v) => callbackValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch to toggle ON (accept self-signed).
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(
        find.text(
          'This makes connections vulnerable to '
          'interception. Continue?',
        ),
        findsOneWidget,
      );

      // Callback should NOT have been called yet.
      expect(callbackValue, isNull);
    });

    testWidgets('confirming dialog flips the value', (tester) async {
      bool? callbackValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TlsToggleWidget(
              value: false,
              onChanged: (v) => callbackValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch to toggle ON.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Confirm.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(callbackValue, isTrue);
    });

    testWidgets('canceling dialog keeps value unchanged', (tester) async {
      bool? callbackValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TlsToggleWidget(
              value: false,
              onChanged: (v) => callbackValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch to toggle ON.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Callback should NOT have been called.
      expect(callbackValue, isNull);
    });

    testWidgets('toggling OFF (enabling TLS) applies immediately '
        'without dialog', (tester) async {
      bool? callbackValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TlsToggleWidget(
              value: true,
              onChanged: (v) => callbackValue = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch to toggle OFF (enable TLS).
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Should apply immediately — no dialog.
      expect(
        find.text(
          'This makes connections vulnerable to '
          'interception. Continue?',
        ),
        findsNothing,
      );
      expect(callbackValue, isFalse);
    });
  });
}
