import 'package:crispy_tivi/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('global navigation excludes Sources and Player', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CrispyTiviApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sources'), findsNothing);
    expect(find.text('Player'), findsNothing);
  });

  testWidgets('sources live under settings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CrispyTiviApp());

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('General'), findsWidgets);
    expect(find.byKey(const Key('settings-sidebar-Sources')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('settings-sidebar-Sources')),
    );
    await tester.tap(find.byKey(const Key('settings-sidebar-Sources')));
    await tester.pumpAndSettle();

    expect(find.text('Home Fiber IPTV'), findsOneWidget);
    expect(find.text('Manage sources'), findsNothing);
  });

  testWidgets('live tv sidebar owns only subviews, groups live in content', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CrispyTiviApp());

    await tester.tap(find.text('Live TV'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live-tv-sidebar-Channels')), findsOneWidget);
    expect(find.byKey(const Key('live-tv-sidebar-Guide')), findsOneWidget);
    expect(find.byKey(const Key('live-tv-sidebar-All')), findsNothing);
    expect(find.byKey(const Key('live-tv-group-allChannels')), findsOneWidget);
  });

  testWidgets('media sidebar owns subviews while scope lives in content', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CrispyTiviApp());

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-sidebar-Movies')), findsOneWidget);
    expect(find.byKey(const Key('media-sidebar-Series')), findsOneWidget);
    expect(find.byKey(const Key('media-scope-featured')), findsOneWidget);
    expect(find.byKey(const Key('media-scope-library')), findsOneWidget);
  });
}
