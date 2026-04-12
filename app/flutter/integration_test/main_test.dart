import 'package:crispy_tivi/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell navigation smoke', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CrispyTiviApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell-utility-settings')));
    await tester.pumpAndSettle();
    expect(find.text('General'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('settings-sidebar-Sources')),
    );
    await tester.tap(find.byKey(const Key('settings-sidebar-Sources')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('source-item-Home Fiber IPTV')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('shell-route-search')));
    await tester.pumpAndSettle();
    expect(find.text('Search live and media titles'), findsOneWidget);
  });
}
