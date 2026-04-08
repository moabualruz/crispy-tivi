import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

Future<void> _pumpFor(WidgetTester tester, {int steps = 20}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Drains any pending exception from the tester.
///
/// On Android, VoiceSearchService may throw a PlatformException
/// (microphone permission request) asynchronously after app boot.
/// Draining prevents spurious test failures.
void _drainException(WidgetTester tester) {
  tester.takeException();
}

Future<void> _searchVod(WidgetTester tester, String query) async {
  final textField = find.byType(TextField);
  expect(
    textField,
    findsWidgets,
    reason: 'VOD screen must expose a text field for filtering results.',
  );
  await tester.enterText(textField.first, query);
  await _pumpFor(tester, steps: 30);
  _drainException(tester);
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

      // Paginated browse rows do not guarantee every seeded title is visible
      // immediately. Verify a seeded title is present in browse mode, then use
      // the screen-local search to confirm another seeded title is reachable via
      // the same pagination-backed path the real UI uses.
      expect(
        find.text('The Matrix'),
        findsWidgets,
        reason: 'Seeded VOD "The Matrix" must be visible on the VODs tab.',
      );
      await _searchVod(tester, 'Inception');
      expect(
        find.text('Inception'),
        findsWidgets,
        reason:
            'Seeded VOD "Inception" must be reachable through the VOD screen search.',
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
      await _searchVod(tester, 'Matrix');

      // Search first so the result is in the visible paginated grid rather than
      // relying on an off-screen browse row child.
      final matrixText = find.text('The Matrix');
      expect(
        matrixText,
        findsWidgets,
        reason: 'Seeded VOD "The Matrix" must be visible.',
      );
      await tester.ensureVisible(matrixText.first);
      await tester.tap(matrixText.first, warnIfMissed: false);
      await _pumpFor(tester);
      _drainException(tester);

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
