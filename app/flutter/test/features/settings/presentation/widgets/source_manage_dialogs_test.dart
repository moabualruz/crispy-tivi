import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/settings/presentation/widgets/source_manage_dialogs.dart';

void main() {
  testWidgets('showAddXtreamDialogFromScreen opens the shared Xtream dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder:
                (context, ref, _) => Scaffold(
                  body: ElevatedButton(
                    onPressed:
                        () => showAddXtreamDialogFromScreen(context, ref),
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add Xtream Codes'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
