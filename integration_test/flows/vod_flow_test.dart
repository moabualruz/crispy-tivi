import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VOD Flow', () {
    testWidgets('VOD tab shows movie names from test data', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      // Pre-populate VOD items.
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to VODs tab.
      await navigateToTab(tester, 'VODs');

      // No exceptions should occur.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);

      // Movie names from TestData.sampleVodItems
      // should be visible.
      final hasMatrix = find.text('The Matrix').evaluate().isNotEmpty;
      final hasInception = find.text('Inception').evaluate().isNotEmpty;

      expect(
        hasMatrix || hasInception,
        isTrue,
        reason:
            'Expected at least one movie name '
            'from test data to be visible on the '
            'VODs tab.',
      );
    });

    testWidgets('VOD screen shows Movies title', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to VODs tab.
      await navigateToTab(tester, 'VODs');

      // The screen title should be "Movies".
      // Series is now a separate nav destination.
      expect(find.text('Movies'), findsWidgets);
    });

    testWidgets('Tapping on a VOD card does not crash', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to VODs tab.
      await navigateToTab(tester, 'VODs');

      // Try to tap on "The Matrix" text if visible.
      final matrixText = find.text('The Matrix');
      if (matrixText.evaluate().isNotEmpty) {
        await tester.tap(matrixText.first);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // No crash should occur from tapping a VOD.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('VOD browser shows "Movies" title', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to VODs tab.
      await navigateToTab(tester, 'VODs');

      // The screen title should be visible.
      expect(find.text('Movies'), findsWidgets);
    });
  });
}
