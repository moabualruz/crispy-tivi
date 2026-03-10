import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

/// Drains any pending exception from the tester.
///
/// On Android, VoiceSearchService may throw a PlatformException
/// (microphone permission request) asynchronously after app boot.
/// Draining prevents spurious test failures.
void _drainException(WidgetTester tester) {
  tester.takeException();
}

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

      expect(find.byType(Scaffold), findsWidgets);

      // Both movies from TestData.sampleVodItems must be visible on the VODs tab.
      expect(
        find.text('The Matrix'),
        findsWidgets,
        reason: 'Seeded VOD "The Matrix" must be visible on the VODs tab.',
      );
      expect(
        find.text('Inception'),
        findsWidgets,
        reason: 'Seeded VOD "Inception" must be visible on the VODs tab.',
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
      _drainException(tester);

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

      // The Matrix was seeded — it must be visible.
      final matrixText = find.text('The Matrix');
      expect(
        matrixText,
        findsWidgets,
        reason: 'Seeded VOD "The Matrix" must be visible.',
      );
      await tester.tap(matrixText.first);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // No crash should occur from tapping a VOD.
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
      _drainException(tester);

      // The screen title should be visible.
      expect(find.text('Movies'), findsWidgets);
    });
  });
}
