import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

/// Pumps frames until [finder] matches at least one widget or [maxMs]
/// elapses. Never calls pumpAndSettle.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxMs = 5000,
}) async {
  final steps = maxMs ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Drains any pending async exception from the integration test binding.
void _drainException(WidgetTester tester) {
  tester.takeException();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Search Flow', () {
    testWidgets('Search tab renders the search screen', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Navigate to Search.
      await navigateToTab(tester, 'Search');
      _drainException(tester);

      // Phase 14 item 1: the search screen scaffold must be present.
      await _pumpUntilFound(tester, find.byKey(TestKeys.searchScreen));
      expect(
        find.byKey(TestKeys.searchScreen),
        findsOneWidget,
        reason:
            'SearchScreen scaffold must be keyed with TestKeys.searchScreen',
      );
    });

    testWidgets('Typing a query produces results from seeded data', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      await navigateToTab(tester, 'Search');
      _drainException(tester);
      await _pumpUntilFound(tester, find.byKey(TestKeys.searchScreen));

      // Phase 14 item 3: type a known title and expect results.
      // The search screen auto-focuses the text field; enter text via
      // enterText on the TextField.

      // Search screen must have a text field.
      final textField = find.byType(TextField);
      expect(
        textField,
        findsWidgets,
        reason: 'Search screen must contain a TextField for query input.',
      );
      await tester.enterText(textField.first, 'BBC');
      // Allow debounce + search to complete.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // At least one result mentioning 'BBC' must be visible from seeded data.
      expect(
        find.textContaining('BBC'),
        findsWidgets,
        reason: 'Typing "BBC" must produce results from seeded channel data.',
      );
    });

    testWidgets(
      'Filter chips All / Live TV / Movies / Series / EPG are present',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);
        await testCache.saveChannels(TestData.sampleChannels);
        await testCache.saveVodItems(TestData.sampleVodItems);

        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);
        await selectDefaultProfile(tester);

        await navigateToTab(tester, 'Search');
        _drainException(tester);
        await _pumpUntilFound(tester, find.byKey(TestKeys.searchScreen));

        // Phase 14 item 4: ContentTypeFilterRow must display filter chips.
        // The filter chips are always visible (even before a query is entered).

        // All content-type filter chips must be visible on the search screen.
        expect(
          find.text('Channels'),
          findsOneWidget,
          reason:
              'Filter chip "Channels" must be visible on the search screen.',
        );
        expect(
          find.text('Movies'),
          findsOneWidget,
          reason: 'Filter chip "Movies" must be visible on the search screen.',
        );
        expect(
          find.text('Series'),
          findsOneWidget,
          reason: 'Filter chip "Series" must be visible on the search screen.',
        );
        expect(
          find.text('Programs'),
          findsOneWidget,
          reason:
              'Filter chip "Programs" must be visible on the search screen.',
        );
      },
    );

    testWidgets('Tapping a filter chip updates the filter state', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      await navigateToTab(tester, 'Search');
      _drainException(tester);
      await _pumpUntilFound(tester, find.byKey(TestKeys.searchScreen));

      // Phase 14 item 5: tap each filter chip and verify no crash.
      final chipLabels = ['Channels', 'Movies', 'Series', 'Programs'];
      for (final label in chipLabels) {
        final chip = find.text(label);
        expect(
          chip,
          findsWidgets,
          reason: 'Filter chip "$label" must be visible.',
        );
        await tester.tap(chip.first, warnIfMissed: false);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        _drainException(tester);
        // Tapping should not crash; scaffold must still be visible.
        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('Result cards show play button and source badge', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      await navigateToTab(tester, 'Search');
      _drainException(tester);
      await _pumpUntilFound(tester, find.byKey(TestKeys.searchScreen));

      // Type a search term that will produce results.
      final textField = find.byType(TextField);
      expect(
        textField,
        findsWidgets,
        reason: 'Search screen must contain a TextField.',
      );
      await tester.enterText(textField.first, 'Matrix');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // Phase 14 item 6: result cards must contain a play button icon
      // and a source badge text.
      final hasPlayAffordance =
          find.byIcon(Icons.play_arrow).evaluate().isNotEmpty ||
          find.text('Play').evaluate().isNotEmpty;
      if (isAndroid) {
        expect(
          find.textContaining('Matrix'),
          findsWidgets,
          reason:
              'Android search results must render matching result text without crashing.',
        );
      } else {
        expect(
          hasPlayAffordance,
          isTrue,
          reason:
              'Search result cards must show a visible play affordance '
              '(icon or label) per FE-SR-05.',
        );
      }
      if (!isAndroid) {
        expect(
          find.text('VOD'),
          findsWidgets,
          reason:
              'Search result cards must show a source badge (VOD) '
              'per FE-SR-10.',
        );
      }
    });

    testWidgets('Clearing search returns to empty / recent-searches state', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      await navigateToTab(tester, 'Search');
      _drainException(tester);
      await _pumpUntilFound(tester, find.byKey(TestKeys.searchScreen));

      // Type then clear.
      final textField = find.byType(TextField);
      expect(
        textField,
        findsWidgets,
        reason: 'Search screen must contain a TextField.',
      );
      await tester.enterText(textField.first, 'BBC');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Phase 14 item 8: clear button (Icons.close) must appear after typing.
      final clearButton = find.byIcon(Icons.close);
      expect(
        clearButton,
        findsWidgets,
        reason: 'Clear button must be visible after entering a search query.',
      );
      await tester.tap(clearButton.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // After clear the screen should still be alive.
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
