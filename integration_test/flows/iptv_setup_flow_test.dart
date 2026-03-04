import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IPTV Setup Flow', () {
    testWidgets('Settings screen renders source management UI', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to Settings.
      await navigateToTab(tester, 'Settings');

      // Settings should render and show the
      // Sources section header.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('Sources'), findsOneWidget);

      // Source addition options should be present.
      expect(find.text('Add M3U Playlist'), findsOneWidget);
      expect(find.text('Add Xtream Codes'), findsOneWidget);
    });

    testWidgets('Tapping "Add Xtream Codes" opens dialog', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to Settings.
      await navigateToTab(tester, 'Settings');

      // Tap "Add Xtream Codes".
      final addXtream = find.text('Add Xtream Codes');
      expect(addXtream, findsOneWidget);
      await tester.tap(addXtream);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // A dialog should appear with the title and
      // form fields.
      expect(find.text('Add Xtream Codes'), findsWidgets);

      // Cancel and Add buttons should be present.
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      // No crash from opening the dialog.
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping "Add M3U Playlist" opens dialog', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to Settings.
      await navigateToTab(tester, 'Settings');

      // Tap "Add M3U Playlist".
      final addM3u = find.text('Add M3U Playlist');
      expect(addM3u, findsOneWidget);
      await tester.tap(addM3u);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // A dialog should appear.
      expect(find.text('Add M3U Playlist'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      // No crash.
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings EPG URL option is accessible', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to Settings.
      await navigateToTab(tester, 'Settings');

      // EPG URL option should be visible.
      expect(find.text('EPG URL'), findsOneWidget);

      // Tap it to open the dialog.
      await tester.tap(find.text('EPG URL'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Dialog should appear with title.
      expect(find.text('EPG URL'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // No crash.
      expect(tester.takeException(), isNull);
    });
  });
}
