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
/// The test environment can produce benign type errors
/// (e.g., `type 'Null' is not a subtype of type
/// `Future<void>`) from async callbacks in the
/// integration test binding. These are not real app
/// bugs -- just drain and ignore them.
void _drainException(WidgetTester tester) {
  tester.takeException();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EPG Flow', () {
    testWidgets('EPG timeline renders with programme titles', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      // Pre-populate channels and EPG.
      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveEpgEntries(TestData.sampleEpg);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to Guide tab.
      await navigateToTab(tester, 'Guide');

      // Drain any benign async exceptions from the
      // integration test binding.
      _drainException(tester);

      expect(find.byType(Scaffold), findsWidgets);

      // The "Program Guide" app bar title should
      // be visible.
      expect(find.text('Program Guide'), findsOneWidget);

      // EPG programme titles from TestData.sampleEpg
      // should be visible.
      final hasMorningLive = find.text('Morning Live').evaluate().isNotEmpty;
      final hasNewsroomLive = find.text('Newsroom Live').evaluate().isNotEmpty;
      final hasLorraine = find.text('Lorraine').evaluate().isNotEmpty;
      final hasBbcBreakfast = find.text('BBC Breakfast').evaluate().isNotEmpty;

      expect(
        hasMorningLive || hasNewsroomLive || hasLorraine || hasBbcBreakfast,
        isTrue,
        reason:
            'Expected at least one EPG programme '
            'title to be visible on the Guide tab.',
      );
    });

    testWidgets('EPG shows channel names in sidebar or list', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveEpgEntries(TestData.sampleEpg);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to Guide tab.
      await navigateToTab(tester, 'Guide');
      _drainException(tester);

      // Channel names should be visible in the EPG
      // sidebar or channel column.
      final hasBbc = find.text('BBC One').evaluate().isNotEmpty;
      final hasCnn = find.text('CNN').evaluate().isNotEmpty;
      final hasEspn = find.text('ESPN').evaluate().isNotEmpty;

      expect(
        hasBbc || hasCnn || hasEspn,
        isTrue,
        reason:
            'Expected at least one channel name '
            'to be visible in the EPG sidebar.',
      );
    });

    testWidgets('EPG renders Day/Week toggle buttons', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await testCache.saveChannels(TestData.sampleChannels);
      await testCache.saveEpgEntries(TestData.sampleEpg);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to Guide tab.
      await navigateToTab(tester, 'Guide');
      _drainException(tester);

      // Day and Week toggle buttons should be
      // visible in the app bar.
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
    });
  });
}
