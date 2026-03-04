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
    testWidgets('Settings screen shows section headers', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to Settings tab.
      await navigateToTab(tester, 'Settings');

      // Settings screen should render.
      expect(find.byType(Scaffold), findsWidgets);

      // No exceptions should occur.
      expect(tester.takeException(), isNull);

      // The "Settings" title should be in the
      // AppBar.
      expect(find.text('Settings'), findsWidgets);

      // Key section headers should be visible.
      // "Sources" is the first section.
      expect(find.text('Sources'), findsOneWidget);

      // "Appearance" and "Playback" sections should
      // also be present (may need scrolling, but
      // Sources is first and always visible).
      final hasAppearance = find.text('Appearance').evaluate().isNotEmpty;
      final hasPlayback = find.text('Playback').evaluate().isNotEmpty;
      final hasSync = find.text('Sync').evaluate().isNotEmpty;

      expect(
        hasAppearance || hasPlayback || hasSync,
        isTrue,
        reason:
            'Expected at least one additional '
            'settings section beyond Sources to '
            'be visible or scrollable.',
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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to Settings tab.
      await navigateToTab(tester, 'Settings');

      // Source addition options should be visible
      // inside the Sources section.
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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to Settings tab.
      await navigateToTab(tester, 'Settings');

      // Scroll down through the settings list.
      // The settings screen uses a ListView, so we
      // fling down to reveal more sections.
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, -500),
        1000,
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // No crash from scrolling.
      expect(tester.takeException(), isNull);

      // Scroll more to reach deeper sections.
      final listView = find.byType(ListView);
      if (listView.evaluate().isNotEmpty) {
        await tester.fling(listView.first, const Offset(0, -500), 1000);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Still no crash.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
