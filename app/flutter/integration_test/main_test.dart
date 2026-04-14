import 'package:crispy_tivi/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell navigation smoke', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CrispyTiviApp());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('failed to load'), findsNothing);
    expect(find.text('CRISPYTIVI'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell-utility-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-search-field')), findsOneWidget);
  });
}
