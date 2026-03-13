import 'package:crispy_tivi/core/widgets/offline_banner.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testApp(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  group('OfflineBanner', () {
    testWidgets('does not fire onReconnect when staying online', (
      tester,
    ) async {
      var reconnected = false;

      await tester.pumpWidget(
        _testApp(OfflineBanner(onReconnect: () => reconnected = true)),
      );
      await tester.pumpAndSettle();

      // Initial state is online — onReconnect should not fire.
      expect(reconnected, isFalse);
    });

    testWidgets('renders without crash when onReconnect is null', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(const OfflineBanner()));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('banner is hidden when online', (tester) async {
      await tester.pumpWidget(_testApp(const OfflineBanner()));
      await tester.pumpAndSettle();

      // When online, the animated size collapses to SizedBox.shrink.
      expect(find.byType(OfflineBanner), findsOneWidget);
      // _BannerContent should not be present when online.
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });
  });
}
