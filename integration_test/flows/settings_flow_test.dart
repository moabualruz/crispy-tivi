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

  group('Settings Flow', () {
    testWidgets('Settings screen shows tab headers', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to Settings tab.
      await navigateToTab(tester, 'Settings');

      // Settings screen should render.
      expect(find.byType(Scaffold), findsWidgets);

      // No exceptions should occur.
      expect(tester.takeException(), isNull);

      // The "Settings" title should be in the AppBar.
      expect(find.text('Settings'), findsWidgets);

      // Tab headers should be visible in the TabBar.
      // "Sources" tab should exist.
      expect(find.text('Sources'), findsOneWidget);

      // Additional tab headers should be present.
      final hasGeneral = find.text('General').evaluate().isNotEmpty;
      final hasPlayback = find.text('Playback').evaluate().isNotEmpty;
      final hasData = find.text('Data').evaluate().isNotEmpty;

      expect(
        hasGeneral || hasPlayback || hasData,
        isTrue,
        reason:
            'Expected at least one additional '
            'settings tab beyond Sources to '
            'be visible.',
      );
    });

    testWidgets('Settings screen shows source addition options', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to Settings tab.
      await navigateToTab(tester, 'Settings');

      // Switch to Sources tab (source options live there).
      final sourcesTab = find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Sources'),
      );
      expect(sourcesTab, findsOneWidget);
      await tester.tap(sourcesTab);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Source addition options should be visible.
      expect(find.text('Add M3U Playlist'), findsOneWidget);
      expect(find.text('Add Xtream Codes'), findsOneWidget);
      expect(find.text('Add Stalker Portal'), findsOneWidget);
      expect(find.text('EPG URL'), findsOneWidget);
    });

    testWidgets('Scrolling through settings does not crash', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to Settings tab.
      await navigateToTab(tester, 'Settings');

      // Scroll down through the settings list.
      // Each tab has its own scrollable content.
      final listView = find.byType(ListView);
      if (listView.evaluate().isNotEmpty) {
        await tester.fling(listView.first, const Offset(0, -500), 1000);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // No crash from scrolling.
      expect(tester.takeException(), isNull);

      // Scroll more to reach deeper sections.
      final listView2 = find.byType(ListView);
      if (listView2.evaluate().isNotEmpty) {
        await tester.fling(listView2.first, const Offset(0, -500), 1000);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // Still no crash.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
