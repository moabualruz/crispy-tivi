import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/settings/presentation/widgets/quick_access_strip.dart';

void main() {
  testWidgets('backup quick action opens Backup & Restore sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: QuickAccessStrip())),
      ),
    );

    await tester.tap(find.text('Backup /\nRestore'));
    await tester.pumpAndSettle();

    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Export Backup'), findsOneWidget);
    expect(find.text('Import Backup'), findsOneWidget);
  });
}
