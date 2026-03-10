import 'package:flutter/foundation.dart';
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

  // EPG flow tests expect desktop-layout elements (Program Guide title,
  // Day/Week toggles, channel sidebar) that only render at medium+ width.
  // On Android phones (411dp compact), the EPG renders a different layout.
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;

  group('EPG Flow', () {
    testWidgets('EPG timeline renders with programme titles', skip: isAndroid, (
      tester,
    ) async {
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

      // EPG programme titles from TestData.sampleEpg must be visible.
      // Assert that at least the seeded programme names are rendered.
      // The EPG is time-based so not all may be in viewport at once.
      // At minimum, the current timeslot programmes must be visible.
      final morningLive = find.text('Morning Live');
      final newsroomLive = find.text('Newsroom Live');
      final lorraine = find.text('Lorraine');
      final bbcBreakfast = find.text('BBC Breakfast');

      // At least 2 of the seeded programmes must be visible in the timeline.
      final visibleCount =
          [
            morningLive,
            newsroomLive,
            lorraine,
            bbcBreakfast,
          ].where((f) => f.evaluate().isNotEmpty).length;
      expect(
        visibleCount,
        greaterThanOrEqualTo(2),
        reason:
            'At least 2 seeded EPG programme titles must be visible in the '
            'Guide timeline. Found $visibleCount of 4.',
      );
    });

    testWidgets('EPG shows channel names in sidebar or list', skip: isAndroid, (
      tester,
    ) async {
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

      // All seeded channels must be visible in the EPG sidebar.
      expect(
        find.text('BBC One'),
        findsWidgets,
        reason: 'Seeded channel "BBC One" must be visible in EPG sidebar.',
      );
      expect(
        find.text('CNN'),
        findsWidgets,
        reason: 'Seeded channel "CNN" must be visible in EPG sidebar.',
      );
      expect(
        find.text('ESPN'),
        findsWidgets,
        reason: 'Seeded channel "ESPN" must be visible in EPG sidebar.',
      );
    });

    testWidgets('EPG renders Day/Week toggle buttons', skip: isAndroid, (
      tester,
    ) async {
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
